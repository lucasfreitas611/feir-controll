#requires -Version 5.1
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSEdition -ne 'Desktop' -or -not [Environment]::Is64BitProcess) {
    throw 'Execute com o Windows PowerShell 5.1 de 64 bits.'
}
$root = $PSScriptRoot
$dist = Join-Path $root 'dist'
$download = Join-Path ([IO.Path]::GetTempPath()) ('feir-build-' + [guid]::NewGuid())
$null = New-Item -ItemType Directory -Path $download
try {
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


    $viiperArchive = Join-Path $download 'libVIIPER.zip'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/DualSenseClient/VIIPER/releases/download/v1.0.1/libVIIPER-windows-amd64.zip' -OutFile $viiperArchive
    if ((Get-FileHash -LiteralPath $viiperArchive -Algorithm SHA256).Hash -ne 'AC1281FEA5663E20B554DF0D2ABF0868B2223CE664465A4B02CF74B3F1C470A9') {
        throw 'O SHA-256 da biblioteca VIIPER não corresponde ao esperado.'
    }
    $viiper = Join-Path $download 'viiper'
    Expand-Archive -LiteralPath $viiperArchive -DestinationPath $viiper
    Copy-Item -LiteralPath (Join-Path $viiper 'libVIIPER.dll') -Destination $dist -Force
    Copy-Item -LiteralPath (Join-Path $viiper 'licenses.txt') -Destination (Join-Path $dist 'VIIPER-licenses.txt') -Force

    foreach ($asset in 'Feir-Controll.ico','FeirControll-Languages.json','LICENSE','Feir-DualShock4.ps1','Feir-Interface.ps1') {
        Copy-Item -LiteralPath (Join-Path $root $asset) -Destination $dist -Force
    }
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    $exe = Join-Path $dist 'Feir Controll.exe'
    $automation = [Management.Automation.PowerShell].Assembly.Location
    $flags = @('/nologo','/target:winexe','/platform:x64',"/out:$exe","/r:$automation",'/r:System.Windows.Forms.dll','/r:System.Drawing.dll')
    $flags += "/win32icon:$(Join-Path $root 'Feir-Controll.ico')"
    $flags += "/win32manifest:$(Join-Path $root 'FeirHost.manifest')"
    $flags += "/r:$(Join-Path (Join-Path $dist 'UCR') $libraries[2])"
    $sources = 'FeirHost.cs','FeirControllTheme.cs','FeirRumble.cs','FeirViiper.cs' | ForEach-Object { Join-Path $root $_ }
    & $csc @flags @sources
    if ($LASTEXITCODE -ne 0) { throw 'Não foi possível compilar o Feir Controll.' }
    Write-Host "Compilado: $exe"
} finally {
    $resolved = (Resolve-Path -LiteralPath $download).Path
    if ([IO.Path]::GetDirectoryName($resolved) -eq [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')) {
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}



