using namespace System.Diagnostics

function Invoke-DelayedTask {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory,Position=0)]
            [timespan]$Delay,
        [Parameter(Mandatory,Position=1)]
            [scriptblock]$Action,
        [Alias('Name')]
            [string]$TaskName = "Waiting"
    )


    [Stopwatch]$Watch = [Stopwatch]::StartNew()
    do {
        $Remaining = $Delay - $Watch.Elapsed
        Write-Progress -Activity $TaskName -SecondsRemaining $Remaining.TotalSeconds -PercentComplete ($Watch.ElapsedTicks / $Delay.Ticks * 100)
        Start-Sleep -Seconds ([Math]::Min($Remaining.TotalSeconds, 1))
    } while($Watch.Elapsed -lt $Delay)
    & $Action
}
