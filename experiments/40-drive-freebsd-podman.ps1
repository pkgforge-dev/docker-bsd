#Requires -Version 7.0
<#
.SYNOPSIS
  Install podman inside the FreeBSD guest that 33-boot-freebsd-whpx.ps1 boots,
  and run a container in it.

.DESCRIPTION
  WHY. `BSD-01` in TODO/bsd.md opens with one gesture:

      podman run --rm -it "example.io/freebsd" -sh

  from Windows, into a real BSD. 33-boot-freebsd-whpx.ps1 got the real BSD, on
  the Windows host's own hypervisor, with no nesting. ⭐ This is the other half:
  whether a container runtime runs inside it, which is what turns a booted
  guest into the thing the entry actually asked for.

  MEASURES, in order, and each one recorded whether it works or not:
    1. that the guest has outbound network at all;
    2. that `pkg` bootstraps and reaches the FreeBSD repository;
    3. that `podman-suite` installs, and what it costs in bytes and seconds;
    4. that podman starts and reports a version;
    5. ⭐ that `podman run` executes something in a container and its stdout
       comes back.

  ⚠ THE RUNTIME UNDERNEATH IS JAILS, through `ocijail`. That is the whole
  reason a FreeBSD host is needed: the same image on a Linux kernel exits 139.
  See this repository's README.md.

  ⛔ THE NETWORK IS OUTBOUND ONLY. `pkg` needs to reach the internet, so unlike
  33 this experiment must attach a network device. It still forwards NOTHING
  inward: no hostfwd, no bridge, no route to the guest. That matters because
  the BASIC-CI image accepts root with an empty password.

  ⚠ DISK. The BASIC-CI image has about 2 GB free after growfs.
  `podman-suite` plus one image fits; a large image may not, and the script
  reports `df` before and after rather than assuming.

.PARAMETER Image
  The OCI image to run in the guest. ⛔ The default is FreeBSD's own published
  runtime image, because this repository's README is explicit that FreeBSD OCI
  images should be consumed and not rebuilt.

.PARAMETER InstallTimeoutSeconds
  Budget for the pkg install. It fetches tens of megabytes over user mode
  networking, which is slower than it looks.

.PARAMETER Cpu, MemoryMiB, VCpus, TimeoutSeconds, QemuPath, ImagePath
  As 33-boot-freebsd-whpx.ps1.

.EXAMPLE
  pwsh -NoProfile -File experiments/40-drive-freebsd-podman.ps1

.NOTES
  ⛔ PositionalBinding is off deliberately. ToolKit's TOOL-03.
  EXIT. 0 a container ran inside the guest, 1 it did not, 2 a prerequisite is
  missing. ⚠ A 1 here is a real result and the output says which step stopped.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$Image = 'ghcr.io/freebsd/freebsd-runtime:15.1',
  [int]$InstallTimeoutSeconds = 1800,
  [string]$Cpu = 'Icelake-Server-v7',
  [int]$MemoryMiB = 3072,
  [int]$VCpus = 4,
  [int]$TimeoutSeconds = 300,
  [string]$QemuPath,
  [string]$ImagePath
)

$ErrorActionPreference = 'Stop'
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
Write-Output '40-drive-freebsd-podman  ----------------------------------------------'
Write-Output "  qemu       $(& $qemu --version | Select-Object -First 1)"
Write-Output "  WHPX       $(Test-Whpx)"
Write-Output "  guest      $imageName, $Cpu, ${VCpus} vcpu, ${MemoryMiB} MiB"
Write-Output "  container  $Image"
Write-Output '  network    user mode, OUTBOUND ONLY. Nothing is forwarded inward.'
Write-Output ''

$qargs = @(
  '-accel', 'whpx',
  '-M', 'q35',
  '-cpu', $Cpu,
  '-smp', "$VCpus",
  '-m', "$MemoryMiB",
  '-drive', "if=none,file=$imageName,format=raw,id=root0",
  '-device', 'virtio-blk-pci,drive=root0',
  '-netdev', 'user,id=n0,ipv6=off',
  '-device', 'virtio-net-pci,netdev=n0',
  '-display', 'none',
  '-no-reboot',
  '-serial', 'stdio',
  '-rtc', 'base=utc,clock=host,driftfix=slew'
)

# Each step is a name, a command, and a budget. ⛔ Keeping them as data is what
# lets the report say which step stopped, instead of "it did not work".
$steps = @(
  @{ Name = 'network up';       Cmd = 'ifconfig -l';                                        Sec = 60 },
  @{ Name = 'address';          Cmd = "ifconfig | grep 'inet ' | grep -v 127.0.0.1";        Sec = 60 },
  @{ Name = 'default route';    Cmd = 'netstat -rn -f inet | grep default';                 Sec = 60 },
  @{ Name = 'dns';              Cmd = 'host -W 5 pkg.freebsd.org || echo NO-RESOLVER';      Sec = 90 },
  @{ Name = 'disk before';      Cmd = 'df -h / | tail -1';                                  Sec = 60 },
  @{ Name = 'pkg bootstrap';    Cmd = 'env ASSUME_ALWAYS_YES=yes pkg bootstrap -y 2>&1 | tail -5'; Sec = 600 },
  @{ Name = 'pkg update';       Cmd = 'pkg update -q 2>&1 | tail -3';                       Sec = 600 },
  @{ Name = 'install podman';   Cmd = 'pkg install -y podman-suite 2>&1 | tail -6';         Sec = $InstallTimeoutSeconds },
  @{ Name = 'podman version';   Cmd = 'podman --version';                                   Sec = 120 },
  @{ Name = 'ocijail present';  Cmd = 'which ocijail || echo NO-OCIJAIL';                   Sec = 60 },
  # The handbook's runtime setup. Each is idempotent and harmless if already so.
  @{ Name = 'enable modules';   Cmd = 'kldload -n linux64 pf 2>/dev/null; sysctl -n security.jail.mount_allowed'; Sec = 120 },
  # ⛔ PODMAN ON FREEBSD DEFAULTS TO THE ZFS STORAGE DRIVER, and the BASIC-CI
  # image is UFS. Without this every podman verb dies with
  # "could not open /dev/zfs ... prerequisites for driver not satisfied".
  # Measured 2026-08-27: that is what stopped the first run of this experiment.
  @{ Name = 'containers conf';  Cmd = 'mkdir -p /usr/local/etc/containers && printf ''[storage]\ndriver = "vfs"\ngraphroot = "/var/db/containers/storage"\nrunroot = "/var/run/containers/storage"\n'' > /usr/local/etc/containers/storage.conf && cat /usr/local/etc/containers/storage.conf'; Sec = 120 },
  # ⛔ THE STORAGE DATABASE OUTRANKS storage.conf. podman records the driver
  # it first used and then refuses to be told otherwise:
  #   User-selected graph driver "vfs" overwritten by graph driver "zfs" from
  #   database - delete libpod local files to resolve.
  # So a first run that failed against zfs poisons every later run, and editing
  # the config is not enough. Measured 2026-08-27, and it cost a whole run.
  @{ Name = 'reset storage';    Cmd = 'rm -rf /var/db/containers/storage /var/run/containers/storage && echo storage-reset'; Sec = 180 },
  @{ Name = 'disk after';       Cmd = 'df -h / | tail -1';                                  Sec = 60 },
  # ⛔ THE TIMECOUNTER. Under WHPX the guest sees the HOST's hypervisor
  # signature, "Microsoft Hv", so FreeBSD selects its Hyper-V timecounter at
  # quality 3000. Measured 2026-08-27: with that selected every Go binary here
  # dies with SIGFPE inside runtime.deductSweepCredit, and moving to ACPI-fast
  # makes podman run succeed. ⚠ THAT IS A CORRELATION, NOT A DIAGNOSIS, and
  # an earlier version of this comment claimed otherwise. With ACPI-fast the
  # clock measurably works, delta_ns=1002101384 across a one-second sleep, and a
  # long-running Go daemon still panics the guest KERNEL in _umtx_op. Something
  # is wrong below the timecounter; this step moves the symptom.
  @{ Name = 'timecounters';     Cmd = 'sysctl -n kern.timecounter.choice; echo "was: $(sysctl -n kern.timecounter.hardware)"'; Sec = 120 },
  @{ Name = 'pick a real one';  Cmd = 'for tc in ACPI-fast TSC-low i8254 HPET; do sysctl kern.timecounter.hardware=$tc >/dev/null 2>&1 && break; done; echo "now: $(sysctl -n kern.timecounter.hardware)"'; Sec = 120 },
  @{ Name = 'podman info';      Cmd = 'podman info --format "{{.Host.OS}}/{{.Host.Arch}} runtime={{.Host.OCIRuntime.Name}}" > /tmp/p.log 2>&1; echo rc=$?; head -12 /tmp/p.log'; Sec = 300 },
  # ⭐ THE ONE THAT MATTERS. A container, running, with its stdout read back.
  # ⛔ THE MARKER IS SPLIT ON PURPOSE. Written whole, it appears in the
  # command line, the guest echoes the command line back, and a test looking for
  # the marker in the output matches the ECHO. The first run of this experiment
  # did exactly that and reported success over a podman that had errored. The
  # guest reassembles it; the echo shows the quotes, the output does not.
  @{ Name = 'podman pull';      Cmd = "podman pull $Image > /tmp/p.log 2>&1; echo rc=`$?; head -12 /tmp/p.log";     Sec = 900 },
  @{ Name = 'podman images';    Cmd = 'podman images --format "{{.Repository}}:{{.Tag}} {{.Size}}" > /tmp/p.log 2>&1; echo rc=$?; head -8 /tmp/p.log'; Sec = 120 },
  @{ Name = 'podman run';       Cmd = "podman run --rm $Image /bin/sh -c 'uname -sr; echo CONTAINER''''-OK' > /tmp/p.log 2>&1; echo rc=`$?; head -20 /tmp/p.log"; Sec = 900 }
)

$ctx = Start-QemuGuest -QemuPath $qemu -QemuArgs $qargs -WorkingDirectory $imageDir
$results = [System.Collections.Generic.List[object]]::new()
$loginSeconds = -1
$ranContainer = $false
try {
  Write-Output "  waiting for a login prompt (budget $TimeoutSeconds s) ..."
  $loginSeconds = Enter-GuestLogin -Ctx $ctx -LoginSeconds $TimeoutSeconds
  if ($loginSeconds -lt 0) {
    Write-Output '  ⛔ never reached a shell within the budget'
  } else {
    Write-Output "  login prompt after ${loginSeconds}s, root shell on ttyu0"
    Write-Output ''
    Write-Output 'GUEST OUTPUT'
    foreach ($s in $steps) {
      $t0 = $ctx.Watch.Elapsed.TotalSeconds
      $r = Invoke-GuestCommand -Ctx $ctx -Command $s.Cmd -Seconds $s.Sec
      $took = [math]::Round($ctx.Watch.Elapsed.TotalSeconds - $t0, 1)
      Write-Output "  [$($s.Name)]  ${took}s"
      Write-Output "  $ $($s.Cmd)"
      if (-not $r.Ok) {
        Write-Output "      ⚠ no prompt came back within $($s.Sec)s"
      }
      foreach ($l in $r.Lines) { Write-Output "      $l" }
      Write-Output ''
      $results.Add([pscustomobject]@{
          Step    = $s.Name
          Ok      = $r.Ok
          Seconds = $took
          Output  = ($r.Lines -join ' / ')
        })
      if ($s.Name -eq 'podman run' -and $r.Ok -and ($r.Lines -join "`n") -match 'CONTAINER-OK') {
        $ranContainer = $true
      }
    }
  }
} finally {
  Write-Output '  shutting the guest down'
  Stop-QemuGuest -Ctx $ctx -Graceful:($loginSeconds -ge 0)
}

$console = $ctx.Text.ToString()
$consolePath = Join-Path $imageDir 'console-podman.log'
Set-Content -LiteralPath $consolePath -Value $console -Encoding utf8

Write-Output ''
Write-Output 'RESULT'
$results | Select-Object Step, Ok, Seconds | Format-Table -AutoSize |
  Out-String -Width 200 | Write-Output
Write-Output "  login prompt    $(if ($loginSeconds -ge 0) { "${loginSeconds}s" } else { 'never reached' })"
Write-Output "  total elapsed   $([math]::Round($ctx.Watch.Elapsed.TotalSeconds,1))s"
Write-Output "  console log     $consolePath ($($console.Length) chars)"
if ($ranContainer) {
  Write-Output '  ⭐ VERDICT      a container ran inside a FreeBSD guest on this Windows'
  Write-Output '                  host. That is the gesture BSD-01 opens with, reached.'
  exit 0
}
Write-Output '  ⛔ VERDICT      no container ran. The table above says which step stopped,'
Write-Output '                  and that is the result: a negative one, with its cause.'
exit 1
