$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:FEIR_BRIDGE_DIR 'UCR'
$env:Path = "$dir;$env:Path"
$providers = Join-Path $dir 'Providers'
Add-Type -Path "$providers\SharpDX_DirectInput\SharpDX.dll", "$providers\SharpDX_DirectInput\SharpDX.DirectInput.dll", "$providers\Core_ViGEm\Nefarius.ViGEmClient.dll"

$mutex = New-Object Threading.Mutex($false, 'Local\CodexFeirDualShock4')
$openRequest = New-Object Threading.EventWaitHandle($false, 'AutoReset', 'Local\CodexFeirOpenWindow')
if (-not $mutex.WaitOne(0)) {
    if ($env:FEIR_START_IN_TRAY -ne '1') { $null = $openRequest.Set() }
    $openRequest.Dispose()
    $mutex.Dispose()
    return
}

$trayIcon = $null
$form = $null
$tray = $null
$menu = $null
$session = @{ Running = $true }

function Close-FeirSlot($slot) {
    if ($slot.Target) { $slot.Target.Dispose(); $slot.Target = $null }
    if ($slot.Joystick) { $slot.Joystick.Dispose(); $slot.Joystick = $null }
    $slot.Connected = $false
    $slot.Input = [bool[]]::new(12)
}

$inputApi = $null
$client = $null
try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $menu = New-Object Windows.Forms.ContextMenuStrip
    $exitItem = $menu.Items.Add('Sair')
    $exitItem.add_Click({ $session.Running = $false }.GetNewClosure())
    $tray = New-Object Windows.Forms.NotifyIcon
    $trayIcon = [Drawing.Icon]::new((Join-Path $env:FEIR_BRIDGE_DIR "Feir-DualShock4.ico"), 16, 16)
    $tray.Icon = $trayIcon
    $tray.ContextMenuStrip = $menu
    $tray.Text = 'DualShock 4 - aguardando controle Feir'
    . ([scriptblock]::Create((Get-Content -LiteralPath (Join-Path $env:FEIR_BRIDGE_DIR 'Feir-Interface.ps1') -Raw)))
    $showSettings = {
        $form.Show()
        if ($form.WindowState -eq 'Minimized') { $form.WindowState = 'Normal' }
        $form.Activate()
    }.GetNewClosure()
    $settingsItem = New-Object Windows.Forms.ToolStripMenuItem('Configurar botões')
    $menu.Items.Insert(0, $settingsItem)
    $settingsItem.add_Click($showSettings)
    $tray.add_DoubleClick($showSettings)
    $tray.Visible = $true
    if ($env:FEIR_START_IN_TRAY -ne '1') { & $showSettings }
    function Update-FeirWindow {
        [Windows.Forms.Application]::DoEvents()
        if ($openRequest.WaitOne(0)) { & $showSettings }
    }
    $inputApi = [SharpDX.DirectInput.DirectInput]::new()
    $client = [Nefarius.ViGEm.Client.ViGEmClient]::new()
    $mapping = [Nefarius.ViGEm.Client.Targets.DualShock4.DualShock4Buttons]
    $buttonNames = 'Triangle','Circle','Cross','Square','ShoulderLeft','ShoulderRight','TriggerLeft','TriggerRight','Share','Options','ThumbLeft','ThumbRight'
    $masks = @($buttonNames | ForEach-Object { [int][Enum]::Parse($mapping, $_) })

    $scanAt = 0
    $paintAt = 0
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($session.Running) {
        Update-FeirWindow
        if (-not $session.Running) { break }
        $now = $clock.ElapsedMilliseconds
        if ($now -ge $scanAt) {
            $scanAt = $now + 900
            $devices = @($inputApi.GetDevices([SharpDX.DirectInput.DeviceClass]::GameControl, [SharpDX.DirectInput.DeviceEnumerationFlags]::AttachedOnly) |
                Where-Object { $_.ProductGuid -like '00010810-*' } | Sort-Object InstanceGuid)
            foreach ($device in $devices) {
                $slot = $session.Slots | Where-Object { $_.DeviceId -eq $device.InstanceGuid } | Select-Object -First 1
                if (-not $slot) {
                    $slot = $session.Slots | Where-Object { -not $_.DeviceId } | Select-Object -First 1
                }
                if (-not $slot) {
                    $slot = $session.Slots | Where-Object { -not $_.Connected -and $_.DeviceId -notin $devices.InstanceGuid } | Select-Object -First 1
                }
                if (-not $slot -or $slot.Connected) { continue }
                $slot.DeviceId = $device.InstanceGuid
                try {
                    $slot.Joystick = [SharpDX.DirectInput.Joystick]::new($inputApi, $device.InstanceGuid)
                    $slot.Joystick.Acquire()
                    $slot.Target = [Nefarius.ViGEm.Client.Targets.DualShock4Controller]::new($client)
                    $slot.Target.Connect()
                    $slot.Report = [Nefarius.ViGEm.Client.Targets.DualShock4.DualShock4Report]::new()
                    $slot.Connected = $true
                } catch { Close-FeirSlot $slot }
            }
        }
        foreach ($slotIndex in 0..1) {
            $slot = $session.Slots[$slotIndex]
            if (-not $slot.Connected) { continue }
            try { $state = $slot.Joystick.GetCurrentState() } catch {
                Close-FeirSlot $slot
                if ($slotIndex -eq $session.Selected) { $session.LearnIndex = -1 }
                continue
            }
            if ($slotIndex -eq $session.Selected -and $session.LearnIndex -ge 0) {
                for ($i = 0; $i -lt 12; $i++) {
                    if ($state.Buttons[$i] -and -not $slot.Input[$i]) {
                        $row = $session.LearnIndex
                        $session.LearnIndex = -1
                        $slot.Draft[$row] = $i
                        $list.Items[$row].SubItems[1].Text = $inputNames[$i + 1]
                        $session.UpdatingPicker = $true
                        $picker.SelectedIndex = $i + 1
                        $session.UpdatingPicker = $false
                        $hint.Text = 'Botão detectado. Clique em Salvar mapeamento.'
                        break
                    }
                }
            }
            $slot.Input = $state.Buttons
            $buttons = 8
            if ($state.PointOfViewControllers[0] -ge 0) {
                $buttons = [int][Math]::Floor($state.PointOfViewControllers[0] / 4500) % 8
            }
            for ($i = 0; $i -lt $masks.Count; $i++) {
                $physical = $slot.Map[$i]
                if ($physical -ge 0 -and $state.Buttons[$physical]) { $buttons = $buttons -bor $masks[$i] }
            }
            $report = $slot.Report
            $report.Buttons = [uint16]$buttons
            $report.LeftThumbX = [byte]($state.X -shr 8)
            $report.LeftThumbY = [byte]($state.Y -shr 8)
            $report.RightThumbX = [byte]($state.RotationZ -shr 8)
            $report.RightThumbY = [byte]($state.Z -shr 8)
            $report.LeftTrigger = [byte](255 * [int](0 -ne ($buttons -band $masks[6])))
            $report.RightTrigger = [byte](255 * [int](0 -ne ($buttons -band $masks[7])))
            try { $slot.Target.SendReport($report) } catch { Close-FeirSlot $slot }
        }
        if ($now -ge $paintAt) {
            $paintAt = $now + 32
            $connected = @($session.Slots | Where-Object Connected -eq $true).Count
            $trayText = "Feir Controller | $connected de 2 conectados"
            if ($tray.Text -ne $trayText) { $tray.Text = $trayText }
            if ($form.Visible) { Update-FeirStatus }
        }
        Start-Sleep -Milliseconds 8
    }

}
finally {
    if ($form) { $form.Dispose() }
    if ($tray) { $tray.Visible = $false; $tray.Dispose() }
    if ($trayIcon) { $trayIcon.Dispose() }
    if ($menu) { $menu.Dispose() }
    foreach ($slot in $session.Slots) { Close-FeirSlot $slot }
    if ($client) { $client.Dispose() }
    if ($inputApi) { $inputApi.Dispose() }
    $openRequest.Dispose()
    $mutex.ReleaseMutex()
    $mutex.Dispose()
}









