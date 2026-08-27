#Requires -Version 7.0
<#
.SYNOPSIS
  Boot smolBSD's NetBSD rescue image under QEMU on the Windows Hypervisor
  Platform, once per candidate CPU model, and report what each one did.

.DESCRIPTION
  WHY. The first avenue in the ranked list: the shortest path from nothing to a
  BSD kernel running on this machine's own hypervisor, one level deep. It is
  also the only way to settle a prediction that was derived rather than
  measured. The published rule for choosing a CPU model under WHPX keys off the
  host CPU and cannot place Intel family 6 model 154, so it would hand this
  machine the newest model it knows, which is the direction two projects
  measured as wedging QEMU before the guest runs an instruction.

  MEASURES, per CPU model:
    - whether QEMU starts at all, or refuses the model outright;
    - whether it wedges, which shows as a zero-byte serial log and a live
      process still burning CPU at the timeout;
    - whether the NetBSD kernel reaches its banner;
    - whether NetBSD's paravirtual bus attaches, which is what carries
      virtio-mmio and therefore the disk;
    - whether a root device is found.

  ⛔ host AND max ARE IN THE DEFAULT LIST ON PURPOSE. They are the two the
  published advice forbids. A rule nobody re-tested on this host is a rule this
  repository is repeating rather than confirming, and the cost of testing them
  is one timeout each.

  ⭐ -IncludeTcgControl runs the identical command line under TCG. That control
  is what separates "this configuration is wrong" from "WHPX behaves
  differently", and on 2026-08-27 it was the measurement that explained the
  whole result.

.PARAMETER CpuModels
  QEMU -cpu models to try, in order. Each is run once.

.PARAMETER TimeoutSeconds
  How long to let each attempt run before killing it. The rescue image reaches
  its root-device prompt in about 21 s, so 35 is enough to see the outcome.

.PARAMETER IncludeTcgControl
  Also run one attempt under -accel tcg with -cpu qemu64, as a control.

.PARAMETER QemuPath
  Full path to qemu-system-x86_64.exe. Discovered if omitted.

.PARAMETER ArtefactDir
  Directory holding netbsd-SMOL and rescue-amd64.img, as left by
  20-fetch-smolbsd.sh. Defaults to ../.tmp/smolbsd beside this script.

.EXAMPLE
  pwsh -NoProfile -File experiments/30-boot-smolbsd.ps1

.NOTES
  ⛔ PositionalBinding is off deliberately. A PowerShell script called through
  -File with positional binding left on lets an argument list overflow into
  whatever parameter is next in declaration order. That is ToolKit's TOOL-03,
  and it committed under a fabricated author before it was found.

  EXIT. 0 at least one model reached a usable BSD userland, 1 none did but the
  run produced measurements, 2 a prerequisite is missing.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
  [string[]]$CpuModels = @('Icelake-Server-v7', 'kvm64-v1', 'qemu64', 'host', 'max'),
  [int]$TimeoutSeconds = 35,
  [switch]$IncludeTcgControl,
  [string]$QemuPath,
  [string]$ArtefactDir
)

$ErrorActionPreference = 'Stop'

function Find-Qemu {
  param([string]$Explicit)
  if ($Explicit) {
    if (Test-Path -LiteralPath $Explicit) { return (Resolve-Path -LiteralPath $Explicit).Path }
    throw "QemuPath does not exist: $Explicit"
  }
  $onPath = Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue
  if ($onPath) { return $onPath.Source }
  # ⚠ A machine-wide scoop install is not under the user's home. Look in both.
  $candidates = @(
    "$env:USERPROFILE\scoop\apps\qemu\current\qemu-system-x86_64.exe",
    "$env:ProgramData\scoop\apps\qemu\current\qemu-system-x86_64.exe",
    "$env:ProgramFiles\qemu\qemu-system-x86_64.exe"
  )
  foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { return $c } }
  throw 'qemu-system-x86_64.exe not found. Install it: scoop install qemu'
}

$qemu = Find-Qemu -Explicit $QemuPath
if (-not $ArtefactDir) {
  $ArtefactDir = Join-Path (Split-Path -Parent $PSScriptRoot) '.tmp\smolbsd'
}
if (-not (Test-Path -LiteralPath $ArtefactDir)) {
  Write-Error "Artefact directory not found: $ArtefactDir`nRun experiments/20-fetch-smolbsd.sh first."
  exit 2
}
$kernel = Join-Path $ArtefactDir 'netbsd-SMOL'
$image = Join-Path $ArtefactDir 'rescue-amd64.img'
foreach ($f in @($kernel, $image)) {
  if (-not (Test-Path -LiteralPath $f)) {
    Write-Error "Missing $f. Run experiments/20-fetch-smolbsd.sh first."
    exit 2
  }
}

# ⭐ The unelevated capability check, rather than a feature query that needs
# elevation. WinHvPlatform.dll resolves only when the Windows Hypervisor
# Platform feature is installed, so the P/Invoke binding at all is half the
# answer; capability 0 is HypervisorPresent and is the other half.
$whpx = 'unknown'
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
  $whpx = if ($hr -eq 0 -and $val -eq 1) { 'present, hypervisor running' } else { "hr=0x{0:X8} value=$val" -f $hr }
} catch {
  $whpx = "WinHvPlatform.dll did not load: $($_.Exception.Message)"
}

$qemuVersion = (& $qemu --version | Select-Object -First 1)
$hostCpu = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
$hostId = "$env:PROCESSOR_IDENTIFIER"

Write-Output ''
Write-Output '30-boot-smolbsd  ------------------------------------------------------'
Write-Output "  qemu       $qemuVersion"
Write-Output "  binary     $qemu"
Write-Output "  WHPX       $whpx"
Write-Output "  host cpu   $hostCpu"
Write-Output "  host id    $hostId"
Write-Output "  artefacts  $ArtefactDir"
Write-Output "  timeout    $TimeoutSeconds s per attempt"
Write-Output ''

function Invoke-Attempt {
  param(
    [Parameter(Mandatory)][string]$Cpu,
    [Parameter(Mandatory)][string]$Accel,
    [Parameter(Mandatory)][int]$Seconds
  )
  $tag = ("$Accel-$Cpu" -replace '[^A-Za-z0-9]', '_')
  $serial = Join-Path $ArtefactDir "serial-$tag.log"
  Remove-Item -LiteralPath $serial -ErrorAction SilentlyContinue

  $qargs = @(
    '-smp', '1', '-m', '256',
    '-accel', $Accel,
    '-M', 'microvm,rtc=on,acpi=off,pic=off',
    '-cpu', "$Cpu,+invtsc",
    '-kernel', 'netbsd-SMOL',
    '-drive', 'if=none,file=rescue-amd64.img,format=raw,id=hd0',
    '-device', 'virtio-blk-device,drive=hd0',
    '-append', 'console=com root=NAME=rescueroot -v',
    '-global', 'virtio-mmio.force-legacy=false',
    '-display', 'none', '-no-reboot',
    '-serial', "file:serial-$tag.log",
    '-rtc', 'base=utc,clock=host,driftfix=slew'
  )

  # ⚠ ProcessStartInfo.ArgumentList, not Start-Process -ArgumentList. The
  # latter joins the array with spaces and quotes nothing, so the -append value
  # arrives as four separate arguments and QEMU dies on "-z: invalid option".
  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $qemu
  foreach ($a in $qargs) { [void]$psi.ArgumentList.Add($a) }
  # Native Windows binaries get a bare filename, never a path.
  $psi.WorkingDirectory = $ArtefactDir
  $psi.UseShellExecute = $false
  $psi.RedirectStandardError = $true
  $psi.RedirectStandardOutput = $true

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $p = [System.Diagnostics.Process]::Start($psi)
  $errTask = $p.StandardError.ReadToEndAsync()
  [void]$p.StandardOutput.ReadToEndAsync()
  $exited = $p.WaitForExit($Seconds * 1000)
  $sw.Stop()

  $cpuSeconds = -1.0
  $exitCode = $null
  if ($exited) {
    # ⛔ Read the exit code from the process that produced it.
    $exitCode = $p.ExitCode
  } else {
    try { $cpuSeconds = $p.TotalProcessorTime.TotalSeconds } catch { $cpuSeconds = -1.0 }
    $p.Kill($true)
    [void]$p.WaitForExit(5000)
  }
  $stderrText = $errTask.Result

  $log = ''
  $logBytes = 0
  if (Test-Path -LiteralPath $serial) {
    $logBytes = (Get-Item -LiteralPath $serial).Length
    $log = Get-Content -LiteralPath $serial -Raw -ErrorAction SilentlyContinue
  }
  if ($null -eq $log) { $log = '' }

  # QEMU prints a CPUID warning per feature the host lacks. Those are noise
  # here; anything else on stderr is a real refusal and is what gets shown.
  $realErr = @($stderrText -split "`r?`n" |
    Where-Object { $_ -and $_ -notmatch "doesn't support requested feature" })

  $banner = $log -match 'smolBSD'
  $pvBus = $log -match 'pv0 at mainbus0'
  $fwcfg = $log -match 'qemufwcfg0'
  $virtio = $log -match 'virtio0 at'
  $disk = $log -match 'ld0 at virtio0'
  $mounted = $log -match 'root file system|init: |# '
  $noRoot = $log -match 'root device:'

  $verdict =
    if ($exited -and $exitCode -ne 0 -and $logBytes -eq 0) { 'REFUSED' }
    elseif (-not $exited -and $logBytes -eq 0) { 'WEDGED' }
    elseif ($disk -and $mounted -and -not $noRoot) { 'BOOTED' }
    elseif ($disk) { 'DISK, NO USERLAND' }
    elseif ($banner) { 'KERNEL, NO DISK' }
    elseif ($logBytes -gt 0) { 'PARTIAL' }
    else { 'NO OUTPUT' }

  [pscustomobject]@{
    Accel    = $Accel
    Cpu      = $Cpu
    Verdict  = $verdict
    Exited   = $exited
    ExitCode = $exitCode
    Elapsed  = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    CpuSec   = if ($cpuSeconds -ge 0) { [math]::Round($cpuSeconds, 2) } else { $null }
    LogBytes = $logBytes
    Banner   = [bool]$banner
    PvBus    = [bool]$pvBus
    FwCfg    = [bool]$fwcfg
    Virtio   = [bool]$virtio
    Disk     = [bool]$disk
    NoRoot   = [bool]$noRoot
    StdErr   = ($realErr | Select-Object -First 3) -join ' | '
    Serial   = $serial
  }
}

$results = [System.Collections.Generic.List[object]]::new()
$fmt = '  {0,-4} -cpu {1,-20} {2,-18} {3,6}s {4,8} log bytes'
foreach ($cpu in $CpuModels) {
  $r = Invoke-Attempt -Cpu $cpu -Accel 'whpx' -Seconds $TimeoutSeconds
  Write-Output ($fmt -f 'whpx', $cpu, $r.Verdict, $r.Elapsed, $r.LogBytes)
  $results.Add($r)
}
if ($IncludeTcgControl) {
  $r = Invoke-Attempt -Cpu 'qemu64' -Accel 'tcg' -Seconds $TimeoutSeconds
  Write-Output ($fmt -f 'tcg', 'qemu64', $r.Verdict, $r.Elapsed, $r.LogBytes)
  $results.Add($r)
}

Write-Output ''
Write-Output 'RESULT'
$results |
  Select-Object Accel, Cpu, Verdict, Elapsed, CpuSec, LogBytes, Banner, PvBus, FwCfg, Virtio, Disk |
  Format-Table -AutoSize | Out-String -Width 200 | Write-Output

foreach ($r in $results) {
  if ($r.StdErr) { Write-Output "  stderr  $($r.Accel)/$($r.Cpu): $($r.StdErr)" }
}

Write-Output ''
Write-Output 'READING THE COLUMNS'
Write-Output '  Banner  the NetBSD kernel started and printed its version'
Write-Output '  PvBus   NetBSD attached its paravirtual bus, which needs the guest'
Write-Output '          to believe it is virtualised at all'
Write-Output '  FwCfg   the QEMU firmware-config device was found behind that bus'
Write-Output '  Virtio  a virtio-mmio transport attached behind it'
Write-Output '  Disk    ld0 attached, so the root filesystem is reachable'
Write-Output ''

$booted = @($results | Where-Object { $_.Verdict -eq 'BOOTED' })
if ($booted.Count -gt 0) {
  Write-Output "  A BSD userland was reached with: $(($booted | ForEach-Object { "$($_.Accel)/$($_.Cpu)" }) -join ', ')"
  exit 0
}
$kernelOnly = @($results | Where-Object { $_.Banner })
if ($kernelOnly.Count -gt 0) {
  Write-Output "  A BSD KERNEL ran under: $(($kernelOnly | ForEach-Object { "$($_.Accel)/$($_.Cpu)" }) -join ', ')"
  Write-Output '  ⛔ No userland was reached. Compare the PvBus column across'
  Write-Output '     accelerators: that is where the answer is.'
}
exit 1
