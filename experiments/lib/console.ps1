#Requires -Version 7.0
<#
.SYNOPSIS
  Drive a QEMU guest over its serial console: start it, wait for text, type
  into it, run commands, read the answers back.

.DESCRIPTION
  ⛔ THIS FILE EXISTS SO THERE IS ONE COPY. 33-boot-freebsd-whpx.ps1 and
  40-drive-freebsd-podman.ps1 both need to boot a guest and talk to it, and
  ToolKit's forbidden-patterns.md has a row for copy-pasting stream and parsing
  logic into a second place: the copies diverge, and a fix to one never reaches
  the other.

  ⚠ IT IS DOT-SOURCED, NOT RUN. It defines functions and does nothing else.

  Every non-obvious thing in here was measured on 2026-08-27 rather than
  guessed, and the comment on each says which.

.NOTES
  A guest context is a hashtable carrying the process, the accumulated console
  text, and the pending read. Passing it explicitly is what lets two guests
  exist at once, which script scope would not.
#>

function Find-Qemu {
  <#
  .SYNOPSIS  Locate qemu-system-x86_64.exe, or throw saying how to install it.
  #>
  [CmdletBinding(PositionalBinding = $false)]
  param([string]$Explicit)
  if ($Explicit) {
    if (Test-Path -LiteralPath $Explicit) { return (Resolve-Path -LiteralPath $Explicit).Path }
    throw "QemuPath does not exist: $Explicit"
  }
  $onPath = Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }
  # ⚠ A machine-wide scoop install is not under the user's home. Look in both.
  foreach ($c in @(
      "$env:USERPROFILE\scoop\apps\qemu\current\qemu-system-x86_64.exe",
      "$env:ProgramData\scoop\apps\qemu\current\qemu-system-x86_64.exe",
      "$env:ProgramFiles\qemu\qemu-system-x86_64.exe")) {
    if (Test-Path -LiteralPath $c) { return $c }
  }
  throw 'qemu-system-x86_64.exe not found. Install it: scoop install qemu'
}

function Test-Whpx {
  <#
  .SYNOPSIS  Is the Windows Hypervisor Platform installed and running.
  .DESCRIPTION
    ⭐ Unelevated, in one call. WinHvPlatform.dll resolves only when the
    optional feature is installed, so the P/Invoke binding at all is half the
    answer; capability 0 is HypervisorPresent and is the other half. Prefer this
    to Get-WindowsOptionalFeature, which refuses without elevation.
  #>
  [CmdletBinding(PositionalBinding = $false)]
  param()
  try {
    if (-not ('Whp' -as [type])) {
      Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Whp {
  [DllImport("WinHvPlatform.dll")]
  public static extern int WHvGetCapability(uint code, out int buf, uint bufSize, out uint written);
}
'@
    }
    $val = 0; $written = 0
    $hr = [Whp]::WHvGetCapability(0, [ref]$val, 4, [ref]$written)
    if ($hr -eq 0 -and $val -eq 1) { return 'present, hypervisor running' }
    return ('hr=0x{0:X8} value={1}' -f $hr, $val)
  } catch {
    return "WinHvPlatform.dll did not load: $($_.Exception.Message)"
  }
}

function Start-QemuGuest {
  <#
  .SYNOPSIS  Start QEMU with its serial console on a pipe and return a context.
  #>
  [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess, ConfirmImpact = 'Low')]
  param(
    [Parameter(Mandatory)][string]$QemuPath,
    [Parameter(Mandatory)][string[]]$QemuArgs,
    [Parameter(Mandatory)][string]$WorkingDirectory,
    [string]$PromptPattern = 'root@[^\r\n]*# '
  )
  if (-not $PSCmdlet.ShouldProcess($QemuPath, 'start a QEMU guest')) { return $null }
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $QemuPath
  # ⚠ ProcessStartInfo.ArgumentList, never Start-Process -ArgumentList. The
  # latter joins the array with spaces and quotes nothing, so a QEMU -append
  # value arrives as four separate arguments and QEMU dies on
  # "-z: invalid option". Measured 2026-08-27, first attempt.
  foreach ($a in $QemuArgs) { [void]$psi.ArgumentList.Add($a) }
  # ⚠ Native Windows binaries get a bare filename, never a path. Run from the
  # directory instead.
  $psi.WorkingDirectory = $WorkingDirectory
  $psi.UseShellExecute = $false
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true

  $p = [System.Diagnostics.Process]::Start($psi)
  @{
    Process = $p
    ErrTask = $p.StandardError.ReadToEndAsync()
    Buffer  = [char[]]::new(8192)
    Text    = [System.Text.StringBuilder]::new()
    Pending = $null
    Prompt  = $PromptPattern
    Watch   = [System.Diagnostics.Stopwatch]::StartNew()
  }
}

function Step-GuestPump {
  <#
  .SYNOPSIS  Read whatever is available from the console into the context.
  .DESCRIPTION
    ⛔ A pending ReadAsync is kept across calls. Starting a second concurrent
    read on the same stream interleaves and loses bytes.
  #>
  [CmdletBinding(PositionalBinding = $false)]
  param([Parameter(Mandatory)][hashtable]$Ctx, [int]$WaitMs = 200)
  if ($null -eq $Ctx.Pending) {
    $Ctx.Pending = $Ctx.Process.StandardOutput.ReadAsync($Ctx.Buffer, 0, $Ctx.Buffer.Length)
  }
  if ($Ctx.Pending.Wait($WaitMs)) {
    $n = $Ctx.Pending.Result
    $Ctx.Pending = $null
    if ($n -gt 0) { [void]$Ctx.Text.Append($Ctx.Buffer, 0, $n); return $true }
  }
  return $false
}

function Wait-ForPattern {
  <#
  .SYNOPSIS  Pump the console until a regex matches, or the budget runs out.
  #>
  [CmdletBinding(PositionalBinding = $false)]
  param(
    [Parameter(Mandatory)][hashtable]$Ctx,
    [Parameter(Mandatory)][string]$Pattern,
    [Parameter(Mandatory)][int]$Seconds
  )
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    if ($Ctx.Process.HasExited) { [void](Step-GuestPump -Ctx $Ctx); return $false }
    [void](Step-GuestPump -Ctx $Ctx)
    if ($Ctx.Text.ToString() -match $Pattern) { return $true }
  }
  return $false
}

function Get-PromptCount {
  [CmdletBinding(PositionalBinding = $false)]
  param([Parameter(Mandatory)][hashtable]$Ctx)
  ([regex]::Matches($Ctx.Text.ToString(), $Ctx.Prompt)).Count
}

function Wait-ForPrompt {
  <#
  .SYNOPSIS  Wait until one MORE prompt has appeared than the baseline.
  .DESCRIPTION
    ⭐ That is what "the command finished" actually means on a console. Waiting
    for the prompt pattern itself would match the prompt the command was typed
    at and return immediately.
  #>
  [CmdletBinding(PositionalBinding = $false)]
  param(
    [Parameter(Mandatory)][hashtable]$Ctx,
    [Parameter(Mandatory)][int]$Baseline,
    [Parameter(Mandatory)][int]$Seconds
  )
  $deadline = (Get-Date).AddSeconds($Seconds)
  while ((Get-Date) -lt $deadline) {
    if ($Ctx.Process.HasExited) { [void](Step-GuestPump -Ctx $Ctx); return $false }
    [void](Step-GuestPump -Ctx $Ctx)
    if ((Get-PromptCount -Ctx $Ctx) -gt $Baseline) { return $true }
  }
  return $false
}

function Send-Line {
  <#
  .SYNOPSIS  Type a line into the guest console, one character at a time.
  .DESCRIPTION
    ⛔ TYPE SLOWLY, AND THE REASON IS MEASURED. A serial console is a real tty
    with a real input queue. Writing a whole line at once while login(1) or the
    shell is still setting up the line discipline silently DROPS characters. On
    2026-08-27 a marker of "TOOLKIT-READY-789f28b0" reached the shell as
    "TOO789f28b", never matched, and read as "the guest never answered" over a
    guest that had answered correctly.
  #>
  [CmdletBinding(PositionalBinding = $false)]
  param(
    [Parameter(Mandatory)][hashtable]$Ctx,
    [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
    [int]$PerCharMs = 5
  )
  foreach ($ch in $Text.ToCharArray()) {
    $Ctx.Process.StandardInput.Write($ch)
    $Ctx.Process.StandardInput.Flush()
    if ($PerCharMs -gt 0) { Start-Sleep -Milliseconds $PerCharMs }
  }
  $Ctx.Process.StandardInput.Write("`n")
  $Ctx.Process.StandardInput.Flush()
}

function Enter-GuestLogin {
  <#
  .SYNOPSIS  Wait for a login prompt, log in, and land on a shell prompt.
  .OUTPUTS   Seconds to the login prompt, or -1 if it never came.
  #>
  [CmdletBinding(PositionalBinding = $false)]
  param(
    [Parameter(Mandatory)][hashtable]$Ctx,
    [string]$User = 'root',
    [int]$LoginSeconds = 300,
    [int]$ShellSeconds = 90
  )
  if (-not (Wait-ForPattern -Ctx $Ctx -Pattern 'login:' -Seconds $LoginSeconds)) { return -1 }
  $t = [math]::Round($Ctx.Watch.Elapsed.TotalSeconds, 1)
  # ⛔ Let the tty settle. login(1) reopens and reconfigures the line, and
  # anything sent during that is lost.
  Start-Sleep -Milliseconds 750
  Send-Line -Ctx $Ctx -Text $User
  # This image's root has an empty password; some builds still prompt.
  if (Wait-ForPattern -Ctx $Ctx -Pattern 'Password:' -Seconds 5) {
    Send-Line -Ctx $Ctx -Text ''
  }
  if (-not (Wait-ForPattern -Ctx $Ctx -Pattern $Ctx.Prompt -Seconds $ShellSeconds)) { return -1 }
  return $t
}

function Invoke-GuestCommand {
  <#
  .SYNOPSIS  Run one command in the guest and return what it printed.
  .OUTPUTS   A hashtable: Ok, Lines.
  #>
  [CmdletBinding(PositionalBinding = $false)]
  param(
    [Parameter(Mandatory)][hashtable]$Ctx,
    [Parameter(Mandatory)][string]$Command,
    [int]$Seconds = 120
  )
  $baseline = Get-PromptCount -Ctx $Ctx
  $before = $Ctx.Text.Length
  Send-Line -Ctx $Ctx -Text $Command
  $ok = Wait-ForPrompt -Ctx $Ctx -Baseline $baseline -Seconds $Seconds
  $chunk = $Ctx.Text.ToString().Substring($before)
  # Drop the guest's echo of the command itself and the prompt that follows the
  # output. What is left is what the command actually printed.
  #
  # ⛔ COMPARE WITH WHITESPACE REMOVED. A tty wraps the echo at the terminal
  # width and inserts a space, so a literal match on the command text MISSES its
  # own echo and the echo survives into the output. On 2026-08-27 that let an
  # experiment match a success marker against the command line that mentioned
  # it, and report "a container ran" over a podman that had exited with an
  # error. That is the "Fake anything" class in ToolKit's
  # forbidden-patterns.md, produced by this very function.
  $cmdNorm = ($Command -replace '\s', '')
  $lines = @($chunk -split "`r?`n" | ForEach-Object { $_.TrimEnd() } |
    ForEach-Object { ($_ -replace '^root@[^\r\n]*# ', '').TrimEnd() } |
    Where-Object {
      $_ -and
      $_ -notmatch '^root@[^\r\n]*# ?$' -and
      -not (($_ -replace '\s', '').Contains($cmdNorm))
    } |
    Where-Object { $_.Trim() })
  @{ Ok = $ok; Lines = $lines }
}

function Stop-QemuGuest {
  <#
  .SYNOPSIS  Ask the guest to power off, then make sure QEMU is gone.
  #>
  [CmdletBinding(PositionalBinding = $false, SupportsShouldProcess, ConfirmImpact = 'Low')]
  param([Parameter(Mandatory)][hashtable]$Ctx, [switch]$Graceful, [int]$Seconds = 45)
  if (-not $PSCmdlet.ShouldProcess("pid $($Ctx.Process.Id)", 'stop the QEMU guest')) { return }
  if ($Graceful -and -not $Ctx.Process.HasExited) {
    Send-Line -Ctx $Ctx -Text 'poweroff'
    [void](Wait-ForPattern -Ctx $Ctx -Pattern 'Uptime|rebooting|Powering off' -Seconds 20)
    [void]$Ctx.Process.WaitForExit($Seconds * 1000)
  }
  if (-not $Ctx.Process.HasExited) {
    $Ctx.Process.Kill($true)
    [void]$Ctx.Process.WaitForExit(10000)
  }
  $Ctx.Watch.Stop()
}

function Get-QemuStderr {
  <#
  .SYNOPSIS  QEMU's stderr, minus the per-feature CPUID warnings, which are noise.
  #>
  [CmdletBinding(PositionalBinding = $false)]
  param([Parameter(Mandatory)][hashtable]$Ctx)
  $text = $Ctx.ErrTask.Result
  @($text -split "`r?`n" | Where-Object { $_ -and $_ -notmatch "doesn't support requested feature" })
}
