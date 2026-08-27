#Requires -Version 5.1
<#
.SYNOPSIS
  What can this Windows host do about booting a BSD.

.DESCRIPTION
  This repository builds images nothing can run: a BSD image needs a BSD
  kernel, so every route to running one starts with a hypervisor. This script
  answers, for one Windows host, which routes are open before anything is
  downloaded.

  It is a probe, not a gate. A missing tool is data.

  The interesting part is the Windows Hypervisor Platform check. It is a real
  runtime call, not a feature-flag guess:

    - WinHvPlatform.dll only loads when the optional 'Windows Hypervisor
      Platform' feature is installed, so the P/Invoke resolving at all proves
      the feature is present;
    - WHvCapabilityCodeHypervisorPresent is capability code 0, and the 32-bit
      result is 1 only when the Microsoft hypervisor is actually running.

  Both without elevation, which Get-WindowsOptionalFeature needs.

.EXAMPLE
  pwsh -NoProfile -File experiments/10-probe-host.ps1

.NOTES
  Runs on Windows PowerShell 5.1 and PowerShell 7. The Linux half is
  10-probe-host.sh; run that one INSIDE the machine that will host the guest.
#>
[CmdletBinding(PositionalBinding = $false)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Row {
    param([string] $Name, [string] $Value)
    '  {0,-22} {1}' -f $Name, $Value
}

# ⚠ On Windows PowerShell 5.1, curl and wget are ALIASES for Invoke-WebRequest,
# not the real binaries, and an alias has no .Source. Reporting the empty string
# would say 'no curl' on a host that has one, and 'curl present' on one that
# does not. Resolve the alias and say which it is.
function Test-Tool {
    param([string] $Name)
    $c = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $c) { return 'absent' }
    if ($c.CommandType -eq 'Alias') {
        $real = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
                Select-Object -First 1
        if ($real) { return $real.Source + '  (shadowed by an alias)' }
        return 'absent (the name is a PowerShell alias, not a binary)'
    }
    if ($c.Source) { return $c.Source }
    return $c.CommandType.ToString()
}

# Reads HypervisorPresent from WinHvPlatform.dll. Returns a string rather than
# throwing, because every failure mode here is an ANSWER: the feature missing
# is as informative as the capability being false.
function Get-WhpState {
    $src = @'
using System;
using System.Runtime.InteropServices;
public static class ProbeWhp {
  [DllImport("WinHvPlatform.dll")]
  public static extern int WHvGetCapability(uint code, out int buf, uint bufSize, out uint written);
}
'@
    # ⛔ Windows PowerShell 5.1 compiles this by shelling out to csc.exe, which
    # reads the LIB and INCLUDE environment variables and treats an invalid
    # search path in one as a warning. Add-Type compiles warnings-as-errors, so
    # ANY stale directory in LIB fails the whole probe with a message about the
    # C# compiler and nothing about the hypervisor. Measured on this machine: a
    # leftover npcap path in LIB did exactly that. PowerShell 7 uses an
    # in-process compiler and never reads LIB, so this only ever breaks on 5.1.
    $savedLib = $env:LIB
    $savedInclude = $env:INCLUDE
    try {
        $env:LIB = ''
        $env:INCLUDE = ''
        if (-not ('ProbeWhp' -as [type])) {
            Add-Type -TypeDefinition $src -ErrorAction Stop | Out-Null
        }
    } catch {
        return 'the type would not compile: ' + $_.Exception.Message
    } finally {
        $env:LIB = $savedLib
        $env:INCLUDE = $savedInclude
    }
    $val = 0
    $written = [uint32] 0
    try {
        $hr = [ProbeWhp]::WHvGetCapability(0, [ref] $val, 4, [ref] $written)
    } catch {
        return 'WinHvPlatform.dll did not load. The Windows Hypervisor Platform feature is not installed'
    }
    if ($hr -ne 0) {
        return ('WHvGetCapability returned 0x{0:X8}' -f $hr)
    }
    if ($val -eq 1) {
        return 'USABLE. Feature installed and the hypervisor is running'
    }
    return 'feature installed, hypervisor NOT running (capability reported 0)'
}

'host probe (windows)'
''

'HOST'
Write-Row 'os' ([System.Environment]::OSVersion.Version.ToString())
Write-Row 'powershell' $PSVersionTable.PSVersion.ToString()
Write-Row 'arch' $env:PROCESSOR_ARCHITECTURE
Write-Row 'cpu identifier' $env:PROCESSOR_IDENTIFIER

$cpuName = 'unknown'
try {
    $key = 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0'
    $cpuName = (Get-ItemProperty -Path $key -Name ProcessorNameString).ProcessorNameString
} catch {
    $cpuName = 'could not read the registry: ' + $_.Exception.Message
}
Write-Row 'cpu' $cpuName

''
'VIRTUALISATION'
Write-Row 'WHPX' (Get-WhpState)

try {
    Write-Row 'HypervisorPresent' ((Get-CimInstance Win32_ComputerSystem).HypervisorPresent)
} catch {
    Write-Row 'HypervisorPresent' ('unreadable: ' + $_.Exception.Message)
}

$vmms = Get-Service vmms -ErrorAction SilentlyContinue
if ($vmms) { Write-Row 'vmms (Hyper-V)' $vmms.Status } else { Write-Row 'vmms (Hyper-V)' 'not installed' }

''
'TOOLING'
foreach ($t in @('qemu-system-x86_64', 'qemu-img', 'podman', 'docker', 'wsl', 'curl', 'oras', '7z')) {
    Write-Row $t (Test-Tool $t)
}

''
'STOP. THE WHPX CPU-MODEL TRAP, BEFORE YOU RUN QEMU'
'  Do not pass -cpu host and do not pass -cpu max. Both have been measured'
'  wedging the whole QEMU process under WHPX: an empty serial log, an'
'  unresponsive monitor, and seconds of CPU time after twelve minutes.'
'  A NAMED model no newer than this host is what works. A model from a LATER'
'  generation than the host wedges it just as thoroughly.'
'  Start with -cpu Icelake-Server-v7 on Intel, or -cpu kvm64-v1, and record'
'  which one booted.'
''
'This is a probe, not a gate. A missing tool is data.'
exit 0
