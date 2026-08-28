#Requires -Version 7.0
<#
.SYNOPSIS
  Both console primitives are BOUNDED, on the PowerShell side: the read returns
  early and the write returns at all.

.DESCRIPTION
  ⛔ WHY THIS EXISTS. It is the twin of tests/console-bounds.py, and the twin is
  the point: `INF-08` and `INF-10` are defects in `experiments/lib/console.py`,
  and `experiments/lib/console.ps1` is this repository's other copy of the same
  two measured tty rules. ⚠ A fix to one half that is not tested on the other is
  how the pair drifts, which is the failure `check-twins.sh` exists to catch for
  the probe and which nothing covered here.

  ⭐ THE TWO HALVES HAD DIFFERENT ANSWERS, WHICH IS EXACTLY WHY THIS RAN.
  `INF-08` needs a prompt pattern that can only match once; this half's default
  prompt is unanchored, so it never showed the defect. `INF-10` is a write with
  no budget and this half had it in full.

  ⛔ IT NEEDS NO EMULATOR AND NO GUEST. Both cases are about a pipe and a
  timeout, so the guest is a few lines of PowerShell: one that answers like a
  shell on a tty, and one that prints a prompt and then never reads its input
  again, which is the state `INF-09`'s guest reaches.

  ⛔ IT CANNOT HANG AGAINST THE CODE IT WAS WRITTEN TO REFUSE. A test whose
  failure mode is "it never returned" is the same shape as the defect. The
  parameter that carries the budget is checked before anything is written, so a
  half that lost the bound is reported rather than waited on.

.NOTES
  Usage:  pwsh -NoProfile -File tests/console-bounds.ps1
  Exit codes: 0 both bounds hold, 1 one does not, 2 could not run.
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
$root = Split-Path -Parent $here
$lib = Join-Path $root 'experiments/lib/console.ps1'
if (-not (Test-Path -LiteralPath $lib)) {
  Write-Output "console-bounds: missing $lib"
  exit 2
}
. $lib

$script:Pass = 0
$script:Fail = 0
function Write-Ok  { param([string]$M) $script:Pass++; Write-Output "  ok   $M" }
function Write-Bad { param([string]$M) $script:Fail++; Write-Output "  FAIL $M" }

# ⚠ THE ANSWER DELIBERATELY SHARES NO TEXT WITH THE COMMAND. Invoke-GuestCommand
# drops any line containing the command, whitespace removed, which is how it
# removes the tty's own echo. ⛔ That is rule 2 working as designed and it is not
# what this file tests.
$Talker = @'
[Console]::Out.Write("root@guest # ")
[Console]::Out.Flush()
while ($true) {
  $line = [Console]::In.ReadLine()
  if ($null -eq $line) { break }
  [Console]::Out.Write($line + "`r`n")
  [Console]::Out.Write("GUEST-ANSWERED`r`nroot@guest # ")
  [Console]::Out.Flush()
}
'@

# ⛔ A GUEST IN EXACTLY THE STATE `INF-09` MEASURED: it reached a prompt and then
# stopped being scheduled. It never reads stdin again, so the pipe fills and
# stays full.
$Deaf = @'
[Console]::Out.Write("root@guest # ")
[Console]::Out.Flush()
Start-Sleep -Seconds 600
'@

# ⚠ THE HOST'S OWN EXECUTABLE IS THE FAKE GUEST, so this needs nothing on PATH
# that is not already running it.
$Self = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName

function Start-FakeGuest {
  param([Parameter(Mandatory)][string]$Script)
  Start-QemuGuest -QemuPath $Self `
    -QemuArgs @('-NoProfile', '-NonInteractive', '-Command', $Script) `
    -WorkingDirectory $root
}

function Test-RunReturnsEarly {
  <#  ⛔ INF-08. It must return when the command is done, not when the budget is. #>
  $ctx = Start-FakeGuest -Script $Talker
  try {
    if (-not (Wait-ForPattern -Ctx $ctx -Pattern 'root@[^\r\n]*# ' -Seconds 30)) {
      Write-Bad 'the fake guest never printed a prompt; the test cannot run'
      return
    }
    $budget = 30
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $r = Invoke-GuestCommand -Ctx $ctx -Command 'hello' -Seconds $budget
    $watch.Stop()
    $elapsed = $watch.Elapsed.TotalSeconds
    if (-not $r.Ok) {
      Write-Bad 'Invoke-GuestCommand did not see the command finish at all'
    } elseif ($elapsed -gt ($budget / 3)) {
      Write-Bad ("Invoke-GuestCommand took {0:N1}s of a {1}s budget. INF-08." -f $elapsed, $budget)
    } else {
      Write-Ok ("Invoke-GuestCommand returned in {0:N1}s of a {1}s budget" -f $elapsed, $budget)
    }
    if (@($r.Lines) -join '|' -eq 'GUEST-ANSWERED') {
      Write-Ok ("it returned exactly what the guest printed: {0}" -f (@($r.Lines) -join '|'))
    } else {
      Write-Bad ("it returned [{0}], expected [GUEST-ANSWERED]" -f (@($r.Lines) -join '|'))
    }
  } finally {
    Stop-QemuGuest -Ctx $ctx -Confirm:$false
  }
}

function Test-SendIsBounded {
  <#  ⛔ INF-10. It must return against a guest that stopped reading. #>
  if (-not (Get-Command Send-Line).Parameters.ContainsKey('TimeoutMs')) {
    Write-Bad ('Send-Line takes no budget. INF-10: every other function in ' +
      'that file takes one and returns $false; the one that WRITES took none, ' +
      'so it parked in a kernel write and no caller timeout applied.')
    return
  }
  $ctx = Start-FakeGuest -Script $Deaf
  try {
    if (-not (Wait-ForPattern -Ctx $ctx -Pattern 'root@[^\r\n]*# ' -Seconds 30)) {
      Write-Bad 'the deaf guest never printed a prompt; the test cannot run'
      return
    }
    # ⚠ Larger than any pipe buffer this runs on. .NET redirects with a 4 KB
    # pipe on Windows and the kernel gives 64 KB on Linux.
    $flood = 'x' * (256 * 1024)
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $sent = Send-Line -Ctx $ctx -Text $flood -PerCharMs 0 -TimeoutMs 3000
    $watch.Stop()
    $elapsed = $watch.Elapsed.TotalSeconds
    if ($sent) {
      Write-Bad ('Send-Line reported it typed the whole line into a guest ' +
        'that is not reading. It must report $false when it could not, ' +
        'because a partially typed line is a real state the caller has to ' +
        'know about.')
    } elseif ($elapsed -gt 60) {
      Write-Bad ("Send-Line took {0:N0}s to give up on a 3s budget" -f $elapsed)
    } else {
      Write-Ok ("Send-Line gave up after {0:N1}s and said so" -f $elapsed)
    }
  } finally {
    Stop-QemuGuest -Ctx $ctx -Confirm:$false
  }
}

Write-Output "console-bounds (PowerShell $($PSVersionTable.PSVersion))"
Test-RunReturnsEarly
Test-SendIsBounded
Write-Output ''
Write-Output "$script:Pass passed, $script:Fail failed"
if ($script:Fail -gt 0) { exit 1 }
exit 0
