# environment.md

⭐ **What a host needs, per route.** This page answers "will this work on my
machine"; [`LIMITS.md`](LIMITS.md) answers "and what will it cost me", and it is
the only page carrying seconds.

⛔ **Run the probe before trusting any of it.** A different machine changes what
can be proved, and every route below was measured on exactly one.

```bash
sh scripts/doctor/doctor.sh
```

```bash
pwsh -NoProfile -File scripts/doctor/doctor.ps1
```

---

## The machine every number in this repository was taken on

⚠ **One machine.** Stated once, here, so no other page has to carry it.

| | |
| --- | --- |
| host | Windows 11 Pro, build 26200 |
| CPU | 12th Gen Intel Core i7-12700H, reported as `Intel64 Family 6 Model 154 Stepping 3` |
| emulator | QEMU 11.1.0, installed with `scoop install qemu` |
| container engine | podman 5.8.6, with a WSL2 Fedora 44 machine, kernel `7.2.0-WSL2-STABLE` |
| privilege | ⭐ **unelevated throughout** |

⛔ **Nothing here has been measured on a Linux host, on macOS, on arm64, or on
a second Windows machine.** That is the single largest gap in this repository
and [`LIMITS.md`](LIMITS.md) says so.

---

## What each route requires

| route | needs on the host | privilege | measured here |
| --- | --- | --- | --- |
| ⭐ **a container engine, and nothing else** | podman or docker | ⭐ **none** | see [`LIMITS.md`](LIMITS.md) |
| **an emulator on the host, using the host's hypervisor** | QEMU, and the Windows Hypervisor Platform feature | ⭐ none | ✅ |
| **an emulator on the host, no hypervisor** | QEMU | ⭐ none | ✅ |
| **a microvm on nested virtualisation** | a Linux host or WSL2 machine with a writable `/dev/kvm` | ⚠ write access to `/dev/kvm` | ✅ |
| **the Windows Host Compute System, directly** | Windows, and membership of one Windows group | ⛔ **administrator, or Hyper-V Administrators** | ✅ refused |
| **a Hyper-V guest** | the Hyper-V feature | ⛔ administrator | ❌ never built |

---

## ⭐ Checking the Windows hypervisor without administrator

⛔ **Do not reach for the feature query.** It needs elevation and it is not the
question you meant. The runtime check answers it in one call, unelevated:

```powershell
$sig = @"
using System;
using System.Runtime.InteropServices;
public static class Whp {
  [DllImport("WinHvPlatform.dll")]
  public static extern int WHvGetCapability(uint code, out int buf, uint bufSize, out uint written);
}
"@
Add-Type -TypeDefinition $sig
$val = 0; $written = 0
$hr = [Whp]::WHvGetCapability(0, [ref]$val, 4, [ref]$written)
"hr=0x{0:X8} value={1}" -f $hr, $val
```

⭐ **Two facts in one call.** The library resolves only when the optional
platform feature is installed, so the call binding at all is half the answer.
Capability 0 is "a hypervisor is present", and the value is the other half.

---

## ⚠ Checking nested virtualisation inside a WSL2 machine

```bash
wsl -d podman-machine-default -u root -- /bin/sh -c 'ls -l /dev/kvm; cat /sys/module/kvm_intel/parameters/nested'
```

⛔ **From Git Bash that command fails and the error names neither the path nor
the cause**, because the guest's `/bin/sh` is rewritten into a Windows path.
[`conventions/shell.md`](conventions/shell.md) section 7 has the rule; prefix
with `MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*'`, or drive it from PowerShell.

⛔ **And do not put a `$` in the payload.** It is expanded in transit and the
result is re-parsed. A probe loop over a variable reached the guest as an empty
string and printed nothing, which looked exactly like "none of these tools are
installed".

⚠ **That command reads the podman machine, which is the one WSL distribution
this repository talks to directly.** ⛔ **Any OTHER Linux a session needs on
this host is built with `wsl-ephemeral.ps1` and thrown away again**, rather than
installed and kept. [`vendored.md`](vendored.md) carries the rule and the three
things it does not cover.

---

## What is deliberately not required

⭐ Each of these has been assumed necessary at least once, and is not.

| | |
| --- | --- |
| ⛔ administrator, for the recommended route | the emulator talks to the hypervisor through a user-mode interface |
| ⛔ nested virtualisation | it is the floor to fall back to, not the target |
| ⛔ `binfmt_misc`, `qemu-user`, or any cross-execution setup | they solve a different problem. [`traps.md`](traps.md) row 1 |
| ⛔ a BSD machine to build on | the images are assembled from published userlands on ordinary Linux runners |
| ⚠ a network, after the first run | the artefacts are cached, and the boot itself needs nothing |
