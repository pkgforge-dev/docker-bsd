#Requires -Version 7.0
<#
.SYNOPSIS
  Boot FreeBSD on the Windows Hypervisor Platform and run commands in it,
  reading the answers back off the serial console.

.DESCRIPTION
  WHY. 30-boot-smolbsd.ps1 established two things on this machine. QEMU under
  -accel whpx runs a BSD kernel at native speed with a named CPU model, and no
  model in the tried set wedged it. But smolBSD's SMOL kernel reaches its disk
  only through NetBSD's paravirtual bus, and under WHPX that bus never
  attaches, so the kernel ran and the userland never started.

  ⭐ A kernel with ordinary PCI drivers does not have that dependency. FreeBSD's
  GENERIC kernel drives virtio-pci directly and never asks whether it is
  virtualised. This is the same hypervisor, the same accelerator and the same
  CPU model as the experiment that stopped short; only the guest changed.

  MEASURES. Whether a real BSD userland runs on this Windows machine's own
  hypervisor, one level deep, and how long it takes from process start to a
  shell that answers. ⛔ It asserts by running commands in the guest and reading
  their output, not by looking at a boot log for a hopeful string.

  ⭐ NO NETWORK DOOR IS OPENED. FreeBSD's BASIC-CI image accepts root with an
  EMPTY PASSWORD, which is what makes it provisionable with no installer, and
  the cheapest way to handle a door like that is not to open it. The console is
  QEMU's own stdio pipe, reachable only by this process.

  ⛔ AND `-display none` DOES NOT MEAN NO NETWORK. QEMU attaches a DEFAULT
  NIC unless it is told otherwise, so the first version of this script printed
  "network NONE" while the guest brought up `em0`, ran dhclient and took a
  lease on 10.0.2.15. No inbound door was opened, because user mode networking
  forwards nothing without `hostfwd`, but the line was false. `-nic none` is
  what makes it true, and it is passed below whenever -WithNetwork is absent.

.PARAMETER Cpu
  QEMU -cpu model. ⚠ On this machine, measured 2026-08-27, host and max did NOT
  wedge QEMU, against published advice. Prefer a named model anyway: it costs
  nothing and the failure it avoids is expensive. See 30-boot-smolbsd.ps1.

.PARAMETER TimeoutSeconds
  Budget for reaching a login prompt. First boot runs growfs and is the slow one.

.PARAMETER MemoryMiB
  Guest memory.

.PARAMETER VCpus
  Guest processor count.

.PARAMETER WithNetwork
  Attach user mode networking, outbound only. Nothing is forwarded inward.

.PARAMETER Command
  Commands to run in the guest, one per element.

.PARAMETER QemuPath
  Full path to qemu-system-x86_64.exe. Discovered if omitted.

.PARAMETER ImagePath
  The raw image 21-fetch-freebsd-ci.sh leaves in ../.tmp/freebsd.

.EXAMPLE
  pwsh -NoProfile -File experiments/33-boot-freebsd-whpx.ps1

.EXAMPLE
  pwsh -NoProfile -File experiments/33-boot-freebsd-whpx.ps1 -Command 'uname -a','pkg -v'

.NOTES
  ⛔ PositionalBinding is off deliberately. ToolKit's TOOL-03.
  EXIT. 0 a BSD userland answered, 1 it did not, 2 a prerequisite is missing.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$Cpu = 'Icelake-Server-v7',
  [int]$TimeoutSeconds = 300,
  [int]$MemoryMiB = 2048,
  [int]$VCpus = 2,
  [switch]$WithNetwork,
  [string[]]$Command = @(
    'uname -a',
    'freebsd-version',
    'sysctl -n hw.model',
    'sysctl -n hw.ncpu',
    'sysctl -n kern.vm_guest',
    'df -h /',
    'sh -c "echo BSD userland is running as $(id -un) on $(uname -s)"'
  ),
  [string]$QemuPath,
  [string]$ImagePath
)

$ErrorActionPreference = 'Stop'
# ⛔ One copy of the console driver, shared with 40-drive-freebsd-podman.ps1.
. (Join-Path $PSScriptRoot 'lib\console.ps1')

$qemu = Find-Qemu -Explicit $QemuPath
if (-not $ImagePath) {
  $ImagePath = Join-Path (Split-Path -Parent $PSScriptRoot) `
    '.tmp\freebsd\FreeBSD-15.1-RELEASE-amd64-BASIC-CI-ufs.raw'
}
if (-not (Test-Path -LiteralPath $ImagePath)) {
  Write-Error "Image not found: $ImagePath`nRun experiments/21-fetch-freebsd-ci.sh first."
  exit 2
}
$ImagePath = (Resolve-Path -LiteralPath $ImagePath).Path
$imageDir = Split-Path -Parent $ImagePath
$imageName = Split-Path -Leaf $ImagePath

Write-Output ''
Write-Output '33-boot-freebsd-whpx  -------------------------------------------------'
Write-Output "  qemu       $(& $qemu --version | Select-Object -First 1)"
Write-Output "  WHPX       $(Test-Whpx)"
Write-Output "  host cpu   $((Get-CimInstance Win32_Processor | Select-Object -First 1).Name)"
Write-Output "  guest cpu  $Cpu"
Write-Output "  image      $imageName"
Write-Output "  size       $([math]::Round((Get-Item -LiteralPath $ImagePath).Length / 1GB, 2)) GiB"
Write-Output "  network    $(if ($WithNetwork) { 'user mode, outbound only, nothing forwarded in' } else { 'NONE' })"
Write-Output ''

$qargs = @(
  '-accel', 'whpx',
  '-M', 'q35',
  '-cpu', $Cpu,
  '-smp', "$VCpus",
  '-m', "$MemoryMiB",
  # if=none plus an explicit virtio-blk-pci, so the transport is named rather
  # than left to QEMU's if= heuristics.
  '-drive', "if=none,file=$imageName,format=raw,id=root0",
  '-device', 'virtio-blk-pci,drive=root0',
  '-display', 'none',
  '-no-reboot',
  # ⭐ stdio, not mon:stdio. The monitor multiplexed onto the same pipe puts its
  # own banner into the stream this script parses.
  '-serial', 'stdio',
  '-rtc', 'base=utc,clock=host,driftfix=slew'
)
if ($WithNetwork) {
  # ⛔ No hostfwd. Outbound only. The guest's sshd takes root with an empty
  # password on first boot and nothing should be able to reach it.
  $qargs += @('-netdev', 'user,id=n0,ipv6=off', '-device', 'virtio-net-pci,netdev=n0')
} else {
  # ⛔ Not decoration. Without this QEMU attaches a default NIC and the guest
  # gets a working outbound network the header above promised it would not.
  $qargs += @('-nic', 'none')
}

# ⛔ The boot phases, measured rather than attributed. The first version of
# this script reported 117 s and the write-up guessed `growfs`. The console says
# otherwise: the filesystem comes up "CLEAN; SKIPPING CHECKS" and there is no
# growfs line at all, and a second boot took the same 117 s, so it is not a
# one-time first-boot cost either. Guessing a cause is how a number on a report
# becomes a number nobody measured.
$phases = [ordered]@{
  'loader hands off' = '---<<BOOT>>---'
  'kernel banner'    = 'FreeBSD [0-9]+\.[0-9]+-RELEASE'
  'root mounted'     = 'Trying to mount root'
  'rc starts'        = 'Setting hostname'
}

$ctx = Start-QemuGuest -QemuPath $qemu -QemuArgs $qargs -WorkingDirectory $imageDir
$ok = $false
$loginSeconds = -1
$phaseTimes = [ordered]@{}
try {
  Write-Output "  waiting for a login prompt (budget $TimeoutSeconds s) ..."
  foreach ($name in $phases.Keys) {
    if (Wait-ForPattern -Ctx $ctx -Pattern $phases[$name] -Seconds $TimeoutSeconds) {
      $phaseTimes[$name] = [math]::Round($ctx.Watch.Elapsed.TotalSeconds, 1)
    } else {
      $phaseTimes[$name] = $null
    }
  }
  $loginSeconds = Enter-GuestLogin -Ctx $ctx -LoginSeconds $TimeoutSeconds
  if ($loginSeconds -ge 0) {
    Write-Output "  login prompt after ${loginSeconds}s, root shell on ttyu0"
    Write-Output ''
    Write-Output 'GUEST OUTPUT'
    $ok = $true
    foreach ($c in $Command) {
      $r = Invoke-GuestCommand -Ctx $ctx -Command $c
      Write-Output "  $ $c"
      if (-not $r.Ok) {
        Write-Output '      ⚠ no prompt came back within the budget'
        $ok = $false
        continue
      }
      foreach ($l in $r.Lines) { Write-Output "      $l" }
    }
  } else {
    Write-Output '  ⛔ never reached a shell within the budget'
  }
} finally {
  Write-Output ''
  Write-Output '  shutting the guest down'
  Stop-QemuGuest -Ctx $ctx -Graceful:$ok
}

$console = $ctx.Text.ToString()
$consolePath = Join-Path $imageDir 'console-whpx.log'
Set-Content -LiteralPath $consolePath -Value $console -Encoding utf8
$realErr = Get-QemuStderr -Ctx $ctx

Write-Output ''
Write-Output 'RESULT'
Write-Output '  accelerator     whpx, the Windows Hypervisor Platform'
Write-Output "  nesting         NONE. This is the host's own hypervisor."
Write-Output "  cpu model       $Cpu"
Write-Output '  boot phases, from qemu process start:'
$prev = 0.0
foreach ($name in $phaseTimes.Keys) {
  $t = $phaseTimes[$name]
  if ($null -eq $t) {
    Write-Output ("    {0,-18} never seen" -f $name)
  } else {
    Write-Output ("    {0,-18} {1,7}s   (+{2}s)" -f $name, $t, [math]::Round($t - $prev, 1))
    $prev = $t
  }
}
if ($loginSeconds -ge 0) {
  Write-Output ("    {0,-18} {1,7}s   (+{2}s)" -f 'login prompt', $loginSeconds, [math]::Round($loginSeconds - $prev, 1))
}
Write-Output "  login prompt    $(if ($loginSeconds -ge 0) { "${loginSeconds}s" } else { 'never reached' })"
Write-Output "  total elapsed   $([math]::Round($ctx.Watch.Elapsed.TotalSeconds,1))s"
Write-Output "  console log     $consolePath ($($console.Length) chars)"
if ($realErr.Count -gt 0) {
  Write-Output "  qemu stderr     $(($realErr | Select-Object -First 3) -join ' | ')"
}
if ($ok) {
  Write-Output '  ⭐ VERDICT      a FreeBSD userland ran on this Windows host, one hypervisor deep'
  exit 0
}
Write-Output '  ⛔ VERDICT      no userland was reached; read the console log'
exit 1
