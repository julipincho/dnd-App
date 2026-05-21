param(
    [int]$Port = 54621
)

$ErrorActionPreference = "Stop"

function Get-ListeningProcessIds {
    param([int]$TargetPort)

    $rows = netstat -ano -p tcp | Select-String -Pattern ":$TargetPort\s"

    foreach ($row in $rows) {
        $parts = $row.Line -split "\s+" | Where-Object { $_ }
        if ($parts.Count -lt 5) {
            continue
        }

        $localAddress = $parts[1]
        $state = $parts[3]
        $processId = $parts[-1]

        if ($state -ne "LISTENING") {
            continue
        }

        if ($localAddress -notmatch ":$TargetPort$") {
            continue
        }

        if ($processId -match "^\d+$") {
            [int]$processId
        }
    }
}

$processIds = @(Get-ListeningProcessIds -TargetPort $Port | Sort-Object -Unique)

if ($processIds.Count -eq 0) {
    Write-Host "Port $Port is free."
    exit 0
}

foreach ($processId in $processIds) {
    if ($processId -eq $PID) {
        continue
    }

    Write-Host "Stopping process $processId on port $Port..."
    Stop-Process -Id $processId -Force
}

Start-Sleep -Milliseconds 700

$remainingProcessIds = @(Get-ListeningProcessIds -TargetPort $Port | Sort-Object -Unique)

if ($remainingProcessIds.Count -gt 0) {
    Write-Error "Port $Port is still busy. Remaining PID(s): $($remainingProcessIds -join ', ')"
    exit 1
}

Write-Host "Port $Port is free."
