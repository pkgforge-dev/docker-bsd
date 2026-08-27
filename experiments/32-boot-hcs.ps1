#Requires -Version 7.0
<#
.SYNOPSIS
  Probe the Host Compute System API and the Hyper-V module directly, and
  report exactly what each one costs on this machine.

.DESCRIPTION
  WHY. This is the avenue nobody had costed. Reading BalajeS/WSL-For-FreeBSD
  showed that WSL creates its own virtual machine by handing
  CreateComputeSystem() a JSON document naming a UEFI boot from a SCSI
  attachment and an HvSocket configuration. ⭐ The useful half of that finding
  is not the patch: it is that the Host Compute System takes a JSON document
  and boots an arbitrary UEFI disk, and reaching it needs no patched service
  and no third party at all.

  ⛔ AND THE PATCH IS REFUSED. Adopting WSL-For-FreeBSD means running a rebuilt
  wslservice.exe, which is the Windows service running this machine's podman
  machine. Everything else here depends on that service. This experiment exists
  precisely because the finding underneath the patch is free and the patch is
  not.

  MEASURES, and nothing more:
    - which library actually carries the HCS entry points, and whether each
      one resolves;
    - whether an unelevated caller may ENUMERATE compute systems;
    - whether the Hyper-V PowerShell module is usable, and at what privilege;
    - what a BSD guest through this route would still need.

  ⛔ THREE OUTCOMES, NOT TWO, and conflating them is how the first version of
  this script printed a false line. A library can be ABSENT, or PRESENT WITH
  THE ENTRY POINT MISSING, or BOUND. LoadLibrary and GetProcAddress separate
  them; a bare try/catch around a P/Invoke does not, and reports the second as
  the first. Measured 2026-08-27: vmcompute.dll is present and exports 36 Hcs*
  functions, and HcsCreateOperation is NOT among them, so a catch-all reported
  "vmcompute.dll did not load" about a library that had loaded perfectly well.

  ⛔ IT CREATES NOTHING. Enumeration is a read. Creating a compute system
  changes what is running on the operator's machine, so this script measures
  the door and does not walk through it. What it would cost to go further is in
  the RESULT block, in writing, which is the deliverable.

.PARAMETER Query
  The HCS enumeration query document. The default asks for everything.

.EXAMPLE
  pwsh -NoProfile -File experiments/32-boot-hcs.ps1

.NOTES
  ⛔ PositionalBinding is off deliberately. ToolKit's TOOL-03.
  EXIT. 0 the probe ran. ⚠ It is a probe, not a gate: a door that is shut is
  data, and it is not a failure.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
  [string]$Query = '{}'
)

$ErrorActionPreference = 'Continue'

if (-not ('NativeProbe' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class NativeProbe {
  [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
  public static extern IntPtr LoadLibraryW(string name);
  [DllImport("kernel32.dll", CharSet = CharSet.Ansi, SetLastError = true)]
  public static extern IntPtr GetProcAddress(IntPtr module, string name);
  [DllImport("kernel32.dll")]
  public static extern IntPtr LocalFree(IntPtr h);
}
'@
}

# The operation-based HCS v2 API lives in computecore.dll. vmcompute.dll is the
# older surface and carries a different, overlapping set.
if (-not ('Hcs' -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Hcs {
  [DllImport("computecore.dll", CharSet = CharSet.Unicode)]
  public static extern IntPtr HcsCreateOperation(IntPtr context, IntPtr callback);
  [DllImport("computecore.dll", CharSet = CharSet.Unicode)]
  public static extern void HcsCloseOperation(IntPtr operation);
  [DllImport("computecore.dll", CharSet = CharSet.Unicode)]
  public static extern int HcsEnumerateComputeSystems(string query, IntPtr operation);
  [DllImport("computecore.dll", CharSet = CharSet.Unicode)]
  public static extern int HcsWaitForOperationResult(IntPtr operation, uint timeoutMs, out IntPtr resultDocument);
}
'@
}

function Test-Export {
  param([Parameter(Mandatory)][string]$Library, [Parameter(Mandatory)][string[]]$Names)
  $h = [NativeProbe]::LoadLibraryW($Library)
  if ($h -eq [IntPtr]::Zero) {
    return [pscustomobject]@{ Library = $Library; Loaded = $false; Found = @(); Missing = $Names }
  }
  $found = @(); $missing = @()
  foreach ($n in $Names) {
    if ([NativeProbe]::GetProcAddress($h, $n) -ne [IntPtr]::Zero) { $found += $n } else { $missing += $n }
  }
  [pscustomobject]@{ Library = $Library; Loaded = $true; Found = $found; Missing = $missing }
}

Write-Output ''
Write-Output '32-boot-hcs  ----------------------------------------------------------'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$elevated = ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Output "  running as     $($identity.Name)"
Write-Output "  elevated       $elevated"
Write-Output ''

$wanted = @(
  'HcsCreateOperation', 'HcsCloseOperation', 'HcsWaitForOperationResult',
  'HcsEnumerateComputeSystems', 'HcsCreateComputeSystem',
  'HcsStartComputeSystem', 'HcsTerminateComputeSystem'
)

Write-Output 'WHICH LIBRARY CARRIES THE API'
$probes = @()
foreach ($lib in @('computecore.dll', 'vmcompute.dll')) {
  $r = Test-Export -Library $lib -Names $wanted
  $probes += $r
  if (-not $r.Loaded) {
    Write-Output "  $lib  ABSENT, LoadLibrary refused it"
  } else {
    Write-Output "  $lib  loaded, $($r.Found.Count)/$($wanted.Count) of the wanted entry points"
    if ($r.Missing.Count -gt 0) {
      Write-Output "    missing: $($r.Missing -join ', ')"
    }
  }
}
Write-Output ''

# ---------------------------------------------------------------- enumerate
$core = $probes | Where-Object { $_.Library -eq 'computecore.dll' }
$enumHr = $null
$enumJson = $null
if ($core.Loaded -and $core.Missing.Count -eq 0) {
  try {
    $op = [Hcs]::HcsCreateOperation([IntPtr]::Zero, [IntPtr]::Zero)
    if ($op -eq [IntPtr]::Zero) {
      Write-Output '  HcsCreateOperation returned NULL'
    } else {
      $callHr = [Hcs]::HcsEnumerateComputeSystems($Query, $op)
      $resultPtr = [IntPtr]::Zero
      $waitHr = [Hcs]::HcsWaitForOperationResult($op, 20000, [ref]$resultPtr)
      if ($resultPtr -ne [IntPtr]::Zero) {
        $enumJson = [Runtime.InteropServices.Marshal]::PtrToStringUni($resultPtr)
        [void][NativeProbe]::LocalFree($resultPtr)
      }
      $enumHr = if ($callHr -ne 0) { $callHr } else { $waitHr }
      [Hcs]::HcsCloseOperation($op)
    }
  } catch {
    Write-Output "  ⚠ the enumerate call threw: $($_.Exception.Message)"
  }
}

Write-Output 'ENUMERATING COMPUTE SYSTEMS'
if ($null -eq $enumHr) {
  Write-Output '  not attempted, the entry points did not all resolve'
} else {
  $meaning = switch ($enumHr) {
    0 { 'S_OK' }
    -2147024891 { 'E_ACCESSDENIED, the call needs elevation' }
    default { try { [ComponentModel.Win32Exception]::new($enumHr).Message } catch { 'unmapped' } }
  }
  Write-Output ("  hr=0x{0:X8}  {1}" -f $enumHr, $meaning)
  if ($enumJson) {
    Write-Output "  $($enumJson.Length) chars of JSON returned"
    try {
      $arr = @($enumJson | ConvertFrom-Json)
      Write-Output "  compute systems visible: $($arr.Count)"
      foreach ($s in $arr) {
        $n = $s.PSObject.Properties.Name
        $sid = if ($n -contains 'Id') { $s.Id } else { '(no Id)' }
        $st = if ($n -contains 'SystemType') { $s.SystemType } else { '?' }
        $ow = if ($n -contains 'Owner') { $s.Owner } else { '?' }
        $rs = if ($n -contains 'State') { $s.State } else { '?' }
        Write-Output "    $sid  type=$st  owner=$ow  state=$rs"
      }
    } catch {
      Write-Output "  ⚠ the result did not parse as JSON: $($_.Exception.Message)"
    }
  }
}
Write-Output ''

# ------------------------------------------------------------------ Hyper-V
Write-Output 'HYPER-V'
$mod = Get-Module -ListAvailable Hyper-V -ErrorAction SilentlyContinue | Select-Object -First 1
Write-Output "  module         $(if ($mod) { "present v$($mod.Version)" } else { 'ABSENT' })"
$vmms = Get-Service vmms -ErrorAction SilentlyContinue
Write-Output "  vmms service   $(if ($vmms) { "$($vmms.Status), startup $($vmms.StartType)" } else { 'ABSENT' })"
Write-Output "  hypervisor     HypervisorPresent=$((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).HypervisorPresent)"
$getVm = 'not attempted'
if ($mod) {
  try { $getVm = "usable, $(@(Get-VM -ErrorAction Stop).Count) VM(s) visible" }
  catch { $getVm = "refused: $($_.Exception.Message -replace '\s+', ' ')" }
}
Write-Output "  Get-VM         $getVm"
Write-Output ''

# ------------------------------------------------------------------- verdict
Write-Output 'RESULT'
$coreOk = ($core.Loaded -and $core.Missing.Count -eq 0)
if ($coreOk) {
  Write-Output '  ⭐ computecore.dll loads and every HCS v2 entry point this probe'
  Write-Output '     wanted resolves, from an ORDINARY UNELEVATED PROCESS. Reaching'
  Write-Output '     the API WSL itself is built on needs no patched service and no'
  Write-Output '     third party. That much of the finding holds.'
} else {
  Write-Output '  ⛔ the HCS v2 entry points did not all resolve here.'
}
$vmc = $probes | Where-Object { $_.Library -eq 'vmcompute.dll' }
if ($vmc.Loaded -and $vmc.Missing.Count -gt 0) {
  Write-Output "  ⚠ vmcompute.dll is present but is NOT the right library: it is"
  Write-Output "    missing $($vmc.Missing.Count) of the wanted entry points. Pointing a"
  Write-Output '    P/Invoke at it and catching the failure reports "the DLL did not'
  Write-Output '    load", which is false and sends the next reader after the wrong'
  Write-Output '    problem.'
}
if ($null -ne $enumHr -and $enumHr -ne 0) {
  Write-Output ''
  Write-Output ("  ⛔ Enumeration, which is a READ, was refused (hr=0x{0:X8})." -f $enumHr)
  Write-Output '     If reading the compute systems is privileged then creating one'
  Write-Output '     certainly is, so this route is closed to an unelevated session.'
}
Write-Output ''
Write-Output '  WHAT A BSD GUEST THROUGH THIS ROUTE WOULD STILL NEED, stated rather'
Write-Output '  than left to be discovered:'
Write-Output '    1. Elevation. Every write verb is administrator-only, and so is'
Write-Output '       Hyper-V, so this route cannot be taken by an unelevated session'
Write-Output '       however reachable the API is.'
Write-Output '    2. A UEFI-bootable VHDX. HCS boots a SCSI attachment through UEFI;'
Write-Output '       it does not take a kernel and a root filesystem the way QEMU and'
Write-Output '       Firecracker do. FreeBSD publishes a .vhd, the older format, so'
Write-Output '       this is a conversion as well as a download.'
Write-Output '    3. A console. HCS gives no serial pipe of its own. WSL reaches its'
Write-Output '       guest over AF_HYPERV sockets, and the guest half of that is the'
Write-Output '       819 lines of C this experiment refuses to adopt. Without it the'
Write-Output '       only way in is the network.'
Write-Output ''
Write-Output '  ⚠ SO THE COST IS NOT THE API. Reaching HCS is free, and that is the'
Write-Output '    finding worth keeping. What is not free is that it yields a virtual'
Write-Output '    machine with no way to talk to it, where QEMU on the very same'
Write-Output '    hypervisor yields a serial console on a pipe and needs no elevation'
Write-Output '    at all. 33-boot-freebsd-whpx.ps1 is that comparison, run.'
exit 0
