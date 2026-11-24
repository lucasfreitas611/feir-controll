param([string]$Payload, [string]$TestDestination)
$ErrorActionPreference = 'Stop'
$working = Split-Path -Parent $Payload
$source = Join-Path $working 'source'
Expand-Archive -LiteralPath $Payload -DestinationPath $source
$destination = if ($TestDestination) { $TestDestination } else {
    Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Feir Controll'
}
if (-not $TestDestination) {
    $active = Get-Process -Name 'Feir Controll' -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq (Join-Path $destination 'Feir Controll.exe') }
    if ($active) { throw 'Feche o Feir Controll pelo menu da bandeja antes de atualizar.' }
    if (-not (Test-Path -LiteralPath (Join-Path $env:ProgramFiles 'USBip\usbip.exe'))) {
        throw 'Instale o usbip-win2 0.9.8.1 x64 antes de instalar o Feir Controll. Consulte as instruções da versão no GitHub.'
    }
}
$build = [IO.File]::ReadAllText((Join-Path $source 'build.ps1'))
$build = $build.Replace('$PSScriptRoot', '$source')
& ([scriptblock]::Create($build))
$null = New-Item -ItemType Directory -Path $destination -Force
Get-ChildItem -LiteralPath (Join-Path $source 'dist') | Copy-Item -Destination $destination -Recurse -Force
if (-not $TestDestination) {
    $programs = [Environment]::GetFolderPath('Programs')
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut((Join-Path $programs 'Feir Controll.lnk'))
    $link.TargetPath = Join-Path $destination 'Feir Controll.exe'
    $link.WorkingDirectory = $destination
    $link.IconLocation = "$($link.TargetPath),0"
    $link.Save()
}

