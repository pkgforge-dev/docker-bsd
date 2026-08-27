#Requires -Version 7.0
<#
.SYNOPSIS
  Reach the FreeBSD guest's podman from the Windows podman client, and run a
  container in it with `podman -c freebsd run`.

.DESCRIPTION
  WHY. This is the exact gesture `BSD-01` in TODO/bsd.md opens with, and
  the exact command its acceptance names. 33-boot-freebsd-whpx.ps1 got a
  FreeBSD userland onto the Windows host's own hypervisor;
  40-drive-freebsd-podman.ps1 got a container running inside it. ⭐ What is left
  is the client half, and the sweep established that it needs nothing built: a
  podman connection is an ordinary SSH URI to a podman socket, so
  `podman system connection add` is the whole of it.

  MEASURES: whether the Windows podman client, unmodified and with no wrapper
  script, runs a container in a FreeBSD guest on this machine.

  ⛔ THE DOOR THIS OPENS, AND HOW IT IS CLOSED IN THE SAME STEP. FreeBSD's
  BASIC-CI image accepts root over ssh with an EMPTY PASSWORD. This experiment
  must forward a port to reach sshd, so before it forwards anything usable it:

    1. generates a THROWAWAY ed25519 key pair, into the ignored .tmp;
    2. installs the public half in the guest over the serial console, which
       needs no network and no password;
    3. ⛔ sets PermitEmptyPasswords no and PasswordAuthentication no, and
       restarts sshd, so the empty-password door is shut before it is reachable;
    4. binds the forwarded port to 127.0.0.1 ONLY, never 0.0.0.0;
    5. removes the podman connection at the end.

  ⚠ The key is a throwaway for one guest on one machine and is written to the
  ignored .tmp, never to the tree. Delete .tmp to destroy it.

.PARAMETER Port
  Host port to forward to the guest's sshd. ⛔ Bound to 127.0.0.1 only.

.PARAMETER ConnectionName
  The podman connection name to create and then remove.

.PARAMETER Image
  The OCI image to run. FreeBSD's own published runtime image.

.PARAMETER Cpu, MemoryMiB, VCpus, TimeoutSeconds, QemuPath, ImagePath
  As 33-boot-freebsd-whpx.ps1.

.EXAMPLE
  pwsh -NoProfile -File experiments/41-connect-podman-from-windows.ps1

.NOTES
  ⛔ PositionalBinding is off deliberately. ToolKit's TOOL-03.
  EXIT. 0 the Windows client ran a container in the guest, 1 it did not,
  2 a prerequisite is missing.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
  [int]$Port = 52222,
  [string]$ConnectionName = 'freebsd-whpx',
  [string]$Image = 'ghcr.io/freebsd/freebsd-runtime:15.1',
  [string]$Cpu = 'Icelake-Server-v7',
  [int]$MemoryMiB = 3072,
  [int]$VCpus = 4,
  [int]$TimeoutSeconds = 300,
  [string]$QemuPath,
  [string]$ImagePath
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib\console.ps1')

foreach ($t in @('podman', 'ssh-keygen')) {
  if (-not (Get-Command $t -ErrorAction SilentlyContinue)) {
    Write-Error "$t is required and is not on PATH"
    exit 2
  }
}

$qemu = Find-Qemu -Explicit $QemuPath
$scratch = Join-Path (Split-Path -Parent $PSScriptRoot) '.tmp\freebsd'
if (-not $ImagePath) {
  $ImagePath = Join-Path $scratch 'FreeBSD-15.1-RELEASE-amd64-BASIC-CI-ufs.raw'
}
if (-not (Test-Path -LiteralPath $ImagePath)) {
  Write-Error "Image not found: $ImagePath`nRun experiments/21-fetch-freebsd-ci.sh first."
  exit 2
}
$ImagePath = (Resolve-Path -LiteralPath $ImagePath).Path
$imageDir = Split-Path -Parent $ImagePath
$imageName = Split-Path -Leaf $ImagePath

# ---------------------------------------------------------------- the key --
$keyPath = Join-Path $scratch 'guest_ed25519'
if (Test-Path -LiteralPath $keyPath) { Remove-Item -LiteralPath $keyPath, "$keyPath.pub" -Force -ErrorAction SilentlyContinue }
# PowerShell 7 passes an empty string argument through correctly, so -N ''
# really does mean no passphrase. The Windows workaround -N '""' does NOT: it
# sets the passphrase to the two literal characters, and the first thing that
# reads the key then blocks on a prompt forever. Measured 2026-08-27.
& ssh-keygen -t ed25519 -N '' -C 'toolkit-experiment-41' -f $keyPath -q | Out-Null
if (-not (Test-Path -LiteralPath "$keyPath.pub")) {
  Write-Error 'ssh-keygen did not produce a key pair'
  exit 2
}
# Prove the key opens with an EMPTY passphrase before anything depends on it.
# -P '' supplies one explicitly, so this can fail but can never hang.
& ssh-keygen -y -P '' -f $keyPath 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Error 'the generated key is passphrase-protected; ssh would block on a prompt'
  exit 2
}
$pub = (Get-Content -LiteralPath "$keyPath.pub" -Raw).Trim()

Write-Output ''
Write-Output '41-connect-podman-from-windows  ---------------------------------------'
Write-Output "  qemu        $(& $qemu --version | Select-Object -First 1)"
Write-Output "  WHPX        $(Test-Whpx)"
Write-Output "  podman      $(& podman --version)"
Write-Output "  guest       $imageName, $Cpu, ${VCpus} vcpu, ${MemoryMiB} MiB"
Write-Output "  forwarding  127.0.0.1:$Port -> guest 22  ⛔ loopback only"
Write-Output "  key         $keyPath  (throwaway, in ignored scratch)"
Write-Output "  image       $Image"
Write-Output ''

$qargs = @(
  '-accel', 'whpx',
  '-M', 'q35',
  '-cpu', $Cpu,
  '-smp', "$VCpus",
  '-m', "$MemoryMiB",
  '-drive', "if=none,file=$imageName,format=raw,id=root0",
  '-device', 'virtio-blk-pci,drive=root0',
  # ⛔ hostfwd bound to 127.0.0.1 explicitly. Left off, QEMU binds every
  # interface, and the guest's sshd would be on the local network.
  '-netdev', "user,id=n0,ipv6=off,hostfwd=tcp:127.0.0.1:${Port}-:22",
  '-device', 'virtio-net-pci,netdev=n0',
  '-display', 'none',
  '-no-reboot',
  '-serial', 'stdio',
  '-rtc', 'base=utc,clock=host,driftfix=slew'
)

# Each step runs in the guest over the console, before anything is reachable.
$prep = @(
  @{ Name = 'install key';    Cmd = "mkdir -p /root/.ssh && chmod 700 /root/.ssh && printf '%s\n' '$pub' > /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys && wc -l /root/.ssh/authorized_keys"; Sec = 120 },
  # ⛔ Shut the empty-password door in the same breath that opens the port.
  @{ Name = 'close the door'; Cmd = "sed -i '' -e 's/^#*PermitEmptyPasswords.*/PermitEmptyPasswords no/' -e 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' -e 's/^#*PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config && grep -E '^(PermitEmptyPasswords|PasswordAuthentication|PermitRootLogin)' /etc/ssh/sshd_config"; Sec = 120 },
  @{ Name = 'restart sshd';   Cmd = 'service sshd restart 2>&1 | tail -2'; Sec = 180 },
  # ⚠ sshd reverse-resolves the client and this guest has no usable resolver for
  # 10.0.2.2, which costs about 30 s per connection. UseDNS no removes it.
  @{ Name = 'UseDNS no';      Cmd = "printf 'UseDNS no\n' >> /etc/ssh/sshd_config && service sshd restart 2>&1 | tail -1"; Sec = 180 },
  # ⛔ THE TIMECOUNTER, and it changes the outcome without explaining it.
  # Under WHPX the guest selects its Hyper-V timecounter and Go binaries die of
  # SIGFPE; moving to ACPI-fast makes a one-shot podman run succeed. ⚠ It
  # does NOT save the daemon below, which panics the guest kernel in _umtx_op
  # with ACPI-fast already selected and the clock measurably correct.
  @{ Name = 'clock';          Cmd = 'for tc in ACPI-fast TSC-low i8254 HPET; do sysctl kern.timecounter.hardware=$tc >/dev/null 2>&1 && break; done; echo "timecounter: $(sysctl -n kern.timecounter.hardware)"'; Sec = 120 },
  @{ Name = 'storage.conf';   Cmd = 'mkdir -p /usr/local/etc/containers && printf ''[storage]\ndriver = "vfs"\ngraphroot = "/var/db/containers/storage"\nrunroot = "/var/run/containers/storage"\n'' > /usr/local/etc/containers/storage.conf && echo written'; Sec = 120 },
  @{ Name = 'reset storage';  Cmd = 'rm -rf /var/db/containers/storage /var/run/containers/storage && echo storage-reset'; Sec = 180 },
  # The rc script is the documented way in and it did not produce a socket on
  # this image, so this shows its whole output rather than a tail of it.
  @{ Name = 'podman rc';      Cmd = 'sysrc podman_enable=YES >/dev/null 2>&1; service podman start > /tmp/svc.log 2>&1; echo rc=$?; head -10 /tmp/svc.log; ls -l /usr/local/etc/rc.d/ 2>/dev/null | grep -i podman'; Sec = 300 },
  # The fallback: run the API service directly. `podman system service` is what
  # the rc script wraps, and a unix socket at a path we choose is all the client
  # needs, because a podman connection is only an SSH URI to a socket.
  # Does the clock actually advance? The whole timecounter theory rests on this
  # and it had never been tested directly. Two reads a second apart, in
  # nanoseconds, on whichever timecounter is selected.
  @{ Name = 'clock advances';  Cmd = 'a=$(date +%s%N); sleep 1; b=$(date +%s%N); echo "tc=$(sysctl -n kern.timecounter.hardware) delta_ns=$((b-a))"'; Sec = 120 },
  # ⛔ A LONG-RUNNING Go DAEMON IS A HARDER CASE THAN A SHORT COMMAND. With
  # ACPI-fast selected, `podman run` completes; `podman system service`, which
  # stays up and therefore runs many more GC cycles, still died of SIGFPE.
  # So sweep the timecounters and keep the first one the daemon survives on,
  # rather than assuming the one that was good enough for a short command.
  @{ Name = 'podman socket';  Cmd = 'mkdir -p /var/run/podman; for tc in ACPI-fast HPET TSC-low i8254; do sysctl kern.timecounter.hardware=$tc >/dev/null 2>&1 || continue; pkill -f "podman system service" >/dev/null 2>&1; rm -f /var/run/podman/podman.sock; nohup podman system service --time=0 unix:///var/run/podman/podman.sock > /tmp/psvc-$tc.log 2>&1 & sleep 8; if podman --url unix:///var/run/podman/podman.sock version >/dev/null 2>&1; then echo "SOCKET-OK with $tc"; break; fi; echo "failed with $tc: $(head -2 /tmp/psvc-$tc.log | tr \"\\n\" \" \")"; done; echo "final tc=$(sysctl -n kern.timecounter.hardware)"; ls -l /var/run/podman/podman.sock 2>&1'; Sec = 600 }
)

$ctx = Start-QemuGuest -QemuPath $qemu -QemuArgs $qargs -WorkingDirectory $imageDir
$loginSeconds = -1
$sockPath = '/var/run/podman/podman.sock'
$clientRan = $false
$connectionAdded = $false
try {
  Write-Output "  waiting for a login prompt (budget $TimeoutSeconds s) ..."
  $loginSeconds = Enter-GuestLogin -Ctx $ctx -LoginSeconds $TimeoutSeconds
  if ($loginSeconds -lt 0) {
    Write-Output '  ⛔ never reached a shell within the budget'
  } else {
    Write-Output "  login prompt after ${loginSeconds}s, root shell on ttyu0"
    Write-Output ''
    Write-Output 'PREPARING THE GUEST, over the console, before any port is usable'
    foreach ($s in $prep) {
      $r = Invoke-GuestCommand -Ctx $ctx -Command $s.Cmd -Seconds $s.Sec
      Write-Output "  [$($s.Name)]"
      if (-not $r.Ok) { Write-Output "      ⚠ no prompt came back within $($s.Sec)s" }
      foreach ($l in $r.Lines) { Write-Output "      $l" }
    }

    Write-Output ''
    Write-Output 'FROM THE WINDOWS PODMAN CLIENT'
    $uri = "ssh://root@127.0.0.1:$Port$sockPath"
    Write-Output "  $ podman system connection add $ConnectionName $uri"
    & podman system connection remove $ConnectionName 2>$null | Out-Null
    $addOut = & podman system connection add --identity $keyPath $ConnectionName $uri 2>&1
    $addRc = $LASTEXITCODE
    if ($addOut) { $addOut | ForEach-Object { Write-Output "      $_" } }
    Write-Output "      exit $addRc"
    if ($addRc -eq 0) { $connectionAdded = $true }

    if ($connectionAdded) {
      Write-Output "  $ podman -c $ConnectionName version --format '{{.Server.Version}}'"
      $verOut = & podman -c $ConnectionName version --format '{{.Server.Version}}' 2>&1
      Write-Output "      exit $LASTEXITCODE"
      $verOut | ForEach-Object { Write-Output "      $_" }

      # ⭐ The command BSD-01's acceptance names.
      Write-Output "  $ podman -c $ConnectionName run --rm $Image /bin/sh -c 'uname -sr'"
      $runOut = & podman -c $ConnectionName run --rm $Image /bin/sh -c 'uname -sr' 2>&1
      # ⛔ Read the exit code from the command that produced it, before
      # anything else runs.
      $runRc = $LASTEXITCODE
      $runOut | ForEach-Object { Write-Output "      $_" }
      Write-Output "      exit $runRc"
      # ⛔ The test is the client's own exit code AND its stdout. Not one or the
      # other: an exit 0 with no output, or output scraped from an echo, is how
      # the first version of experiment 40 reported a success that had not
      # happened.
      if ($runRc -eq 0 -and (($runOut -join "`n") -match 'FreeBSD\s+\d+\.\d+')) {
        $clientRan = $true
      }
    }
  }
} finally {
  Write-Output ''
  if ($connectionAdded) {
    Write-Output "  removing the podman connection $ConnectionName"
    & podman system connection remove $ConnectionName 2>&1 | Out-Null
  }
  Write-Output '  shutting the guest down'
  Stop-QemuGuest -Ctx $ctx -Graceful:($loginSeconds -ge 0)
}

$console = $ctx.Text.ToString()
$consolePath = Join-Path $imageDir 'console-connect.log'
Set-Content -LiteralPath $consolePath -Value $console -Encoding utf8

Write-Output ''
Write-Output 'RESULT'
Write-Output "  login prompt    $(if ($loginSeconds -ge 0) { "${loginSeconds}s" } else { 'never reached' })"
Write-Output "  total elapsed   $([math]::Round($ctx.Watch.Elapsed.TotalSeconds,1))s"
Write-Output "  console log     $consolePath ($($console.Length) chars)"
Write-Output "  connection      $(if ($connectionAdded) { 'added, and removed again' } else { 'not added' })"
if ($clientRan) {
  Write-Output '  ⭐ VERDICT      the Windows podman client ran a container in a FreeBSD'
  Write-Output '                  guest on this machine, with no wrapper and no patch.'
  Write-Output '                  That is BSD-01''s acceptance command, run.'
  exit 0
}
Write-Output '  ⛔ VERDICT      the client did not run a container. The output above says'
Write-Output '                  where it stopped, and that is the result.'
exit 1
