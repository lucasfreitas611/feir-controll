#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$dist = Join-Path $root 'dist'
$null = New-Item -ItemType Directory -Path $dist -Force
$payload = Join-Path $dist 'setup-payload.zip'
$files = @('FeirHost.cs','FeirControllTheme.cs','FeirRumble.cs','FeirViiper.cs',
    'Feir-DualShock4.ps1','Feir-Interface.ps1','FeirControll-Languages.json',
    'Feir-Controll.ico','FeirHost.manifest','build.ps1','LICENSE') |
    ForEach-Object { Join-Path $root $_ }
Compress-Archive -LiteralPath $files -DestinationPath $payload -Force
try {
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    $exe = Join-Path $dist 'Feir-Controll-Setup-x64.exe'
    $automation = [Management.Automation.PowerShell].Assembly.Location
    $flags = @('/nologo','/target:winexe','/platform:x64',"/out:$exe","/r:$automation",'/r:System.Windows.Forms.dll')
    $flags += "/win32icon:$(Join-Path $root 'Feir-Controll.ico')"
    $flags += "/win32manifest:$(Join-Path $root 'FeirHost.manifest')"
    $flags += "/resource:$payload,Feir.Payload"
    $flags += "/resource:$(Join-Path $root 'Install-Feir.ps1'),Feir.Install"
    & $csc @flags (Join-Path $root 'FeirSetup.cs')
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível gerar o instalador.' }
    Write-Host "Instalador: $exe"
} finally {
    Remove-Item -LiteralPath $payload
}


