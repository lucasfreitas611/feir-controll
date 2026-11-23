param([string]$Payload, [string]$TestDestination)
$ErrorActionPreference = 'Stop'
if (-not [Environment]::Is64BitProcess) { throw 'Este instalador requer Windows x64.' }
$working = Split-Path -Parent $Payload
$dist = Join-Path $working 'app'
$download = $working
Expand-Archive -LiteralPath $Payload -DestinationPath $dist
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $archive = Join-Path $download 'UCR.zip'
    $url = 'https://github.com/Snoothy/UCR/releases/download/v0.9.0/UCR_v0.9.0.zip'
    Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $archive
    $expected = 'AC32981FA27950F11C2772152480F2A6B03E8C26D8F645397ABCF5ACD95BDE49'
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expected) {
        throw 'O SHA-256 das dependências não corresponde ao esperado.'
    }
    $extracted = Join-Path $download 'UCR'
    Expand-Archive -LiteralPath $archive -DestinationPath $extracted
    $libraries = @(
        'Providers\SharpDX_DirectInput\SharpDX.dll'
        'Providers\SharpDX_DirectInput\SharpDX.DirectInput.dll'
        'Providers\Core_ViGEm\Nefarius.ViGEmClient.dll'
    )
    foreach ($library in $libraries) {
        $destination = Join-Path (Join-Path $dist 'UCR') $library
        $null = New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force
        Copy-Item -LiteralPath (Join-Path $extracted $library) -Destination $destination -Force
    }
    $client = [Reflection.Assembly]::Load([IO.File]::ReadAllBytes((Join-Path $extracted $libraries[2])))
    $resource = $client.GetManifestResourceStream('costura64.vigemclient.dll')
    if ($null -eq $resource) { throw 'Biblioteca nativa ViGEm x64 ausente.' }
    try {
        $file = [IO.File]::Create((Join-Path $dist 'UCR\vigemclient.dll'))
        try { $resource.CopyTo($file) } finally { $file.Dispose() }
    } finally { $resource.Dispose() }


$destination = if ($TestDestination) {
    $TestDestination
} else {
    Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Feir Controller'
}
if (-not $TestDestination) {
    $active = Get-Process -Name 'Feir Controller' -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq (Join-Path $destination 'Feir Controller.exe') }
    if ($active) { throw 'Feche o Feir Controller pelo menu da bandeja antes de atualizar.' }
}
$null = New-Item -ItemType Directory -Path $destination -Force
Get-ChildItem -LiteralPath $dist | Copy-Item -Destination $destination -Recurse -Force
if (-not $TestDestination) {
    $programs = [Environment]::GetFolderPath('Programs')
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut((Join-Path $programs 'Feir Controller.lnk'))
    $link.TargetPath = Join-Path $destination 'Feir Controller.exe'
    $link.WorkingDirectory = $destination
    $link.IconLocation = "$($link.TargetPath),0"
    $link.Save()
}

