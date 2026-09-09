Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class PowerState {
    [DllImport("kernel32.dll")]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
"@

$ES_CONTINUOUS = [uint32]0x80000000
$ES_SYSTEM_REQUIRED = [uint32]0x00000001
$ES_DISPLAY_REQUIRED = [uint32]0x00000002
$flags = $ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED -bor $ES_DISPLAY_REQUIRED

try {
    [PowerState]::SetThreadExecutionState($flags) | Out-Null
    Write-Output "Keep-awake is active. Press Ctrl+C to stop."
    while ($true) {
        Start-Sleep -Seconds 30
        [PowerState]::SetThreadExecutionState($flags) | Out-Null
    }
}
finally {
    [PowerState]::SetThreadExecutionState($ES_CONTINUOUS) | Out-Null
}
