param(
    [Parameter(Mandatory=$true)][string]$Wallet,
    [string]$Worker = 'windows',
    [string]$Pool = 'vela.suprnova.cc:7601',
    [string]$Devices = '0',
    [string]$ModelDir = "$PSScriptRoot/models",
    [int]$Batch = 0,
    [int]$Lanes = 0,
    [switch]$Tls
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$model = Join-Path $ModelDir 'sd-turbo-int.poisd'
$expected = 'ba38ab96b3398e22ea631d8a457350f91833e57463199d063663308513651f36'
if (!(Test-Path $model)) {
    New-Item -ItemType Directory -Force $ModelDir | Out-Null
    $part = "$model.download-$PID"
    Write-Host 'Downloading sd-turbo-int model (~1.2 GB, one time)...'
    $sources = @('https://vela.suprnova.cc/dl/sd-turbo-int.poisd',
                 'https://www.suprnova.cc/dl/sd-turbo-int.poisd',
                 'https://huggingface.co/valereseach/vela-sd-turbo-int-v2/resolve/main/sd-turbo-int.poisd')
    try {
        foreach ($url in $sources) {
            Write-Host "Source: $url"
            & curl.exe --fail --location --retry 3 --connect-timeout 15 --proto '=https' --proto-redir '=https' `
                --output $part $url
            if (!$LASTEXITCODE -and (Test-Path $part) -and
                (Get-FileHash $part -Algorithm SHA256).Hash.ToLowerInvariant() -eq $expected) {
                Move-Item $part $model
                break
            }
            Write-Host "Download failed or checksum mismatch: $url"
            if (Test-Path $part) { Remove-Item $part }
        }
        if (!(Test-Path $model)) { throw 'Model download failed (all sources)' }
    } finally { if (Test-Path $part) { Remove-Item $part } }
}
if ((Get-FileHash $model -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) { throw 'Wrong model file; expected sd-turbo-int.poisd' }
$minerArgs = @('-o', $Pool, '-u', "$Wallet.$Worker", '--devices', $Devices, '--model', $model)
if ($Batch -gt 0) { $minerArgs += @('--batch', $Batch) }
if ($Lanes -gt 0) { $minerArgs += @('--lanes', $Lanes) }
if ($Tls)         { $minerArgs += '--tls' }
& "$PSScriptRoot/supr-meow-vela.exe" @minerArgs
exit $LASTEXITCODE
