param(
    [string]$HostName = "127.0.0.1",
    [int]$Port = 54621,
    [string]$FlutterBin = "",
    [switch]$OpenBrowser
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$freePortScript = Join-Path $PSScriptRoot "free_web_port.ps1"

Set-Location $repoRoot

$gitCmd = Join-Path $env:ProgramFiles "Git\cmd"
if ((Test-Path $gitCmd) -and (($env:Path -split ';') -notcontains $gitCmd)) {
    $env:Path = "$gitCmd;$env:Path"
}

if ([string]::IsNullOrWhiteSpace($FlutterBin)) {
    if (-not [string]::IsNullOrWhiteSpace($env:FLUTTER_BIN)) {
        $FlutterBin = $env:FLUTTER_BIN
    } else {
        $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
        if ($flutterCommand) {
            $FlutterBin = $flutterCommand.Source
        } else {
            $FlutterBin = Join-Path $env:USERPROFILE "development\flutter\bin\flutter.bat"
        }
    }
}

if (-not (Test-Path $FlutterBin)) {
    throw "No se encontro Flutter en '$FlutterBin'. Abre una terminal nueva o ejecuta pasando -FlutterBin 'C:\Users\julip\development\flutter\bin\flutter.bat'."
}

Write-Host "Stitch web run: liberando puerto $Port..."
& $freePortScript -Port $Port

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($OpenBrowser) {
    $appUrl = "http://${HostName}:${Port}"
    Write-Host "Stitch web run: el navegador se abrira cuando $appUrl responda."
    $openerCommand = @"
`$url = '$appUrl'
for (`$i = 0; `$i -lt 90; `$i++) {
    try {
        Invoke-WebRequest -Uri `$url -UseBasicParsing -TimeoutSec 2 | Out-Null
        Start-Process `$url
        exit 0
    } catch {
        Start-Sleep -Seconds 1
    }
}
"@
    Start-Process `
        -FilePath powershell.exe `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $openerCommand) `
        -WindowStyle Hidden
}

Write-Host "Stitch web run: iniciando Flutter Web Server en http://${HostName}:${Port}"
Write-Host "Stitch web run: usa r para hot reload y q para salir."

& $FlutterBin `
    run `
    -d web-server `
    --web-hostname $HostName `
    --web-port $Port `
    --dart-define=SUPABASE_URL=https://pzunblkcrpusanbnajue.supabase.co `
    --dart-define=SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB6dW5ibGtjcnB1c2FuYm5hanVlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NzAwNTcsImV4cCI6MjA5MjU0NjA1N30.gco0_S1p-dnSTpb7b3sVErhxRSid-W3PptubcgKKV-0 `
    --dart-define=SUPABASE_IMAGE_BUCKET=user-images

exit $LASTEXITCODE
