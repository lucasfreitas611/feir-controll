$ErrorActionPreference = 'Stop'
$usbip = Join-Path $env:ProgramFiles 'USBip'
if (Test-Path -LiteralPath (Join-Path $usbip 'usbip.exe')) {
    $env:Path = "$usbip;$env:Path"
}
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
    if ($slot.Rumble) { $slot.Rumble.Dispose(); $slot.Rumble = $null }
    if ($slot.Target) { $slot.Target.Dispose(); $slot.Target = $null }
    if ($slot.Joystick) { $slot.Joystick.Dispose(); $slot.Joystick = $null }
    $slot.Connected = $false
    $slot.DigitalDpad = $false
    [Array]::Clear($slot.Input, 0, $slot.Input.Length)
}

$inputApi = $null
$client = $null
try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $menu = New-Object Windows.Forms.ContextMenuStrip
    $exitItem = $menu.Items.Add('Sair')
    $exitItem.add_Click({ $session.Running = $false }.GetNewClosure())
    $tray = New-Object Windows.Forms.NotifyIcon
    $trayIcon = [Drawing.Icon]::new((Join-Path $env:FEIR_BRIDGE_DIR "Feir-Controll.ico"), [Windows.Forms.SystemInformation]::SmallIconSize.Width, [Windows.Forms.SystemInformation]::SmallIconSize.Height)
    $tray.Icon = $trayIcon
    $tray.ContextMenuStrip = $menu
    $tray.Text = 'Feir Controll | aguardando controle'
    . ([scriptblock]::Create((Get-Content -LiteralPath (Join-Path $env:FEIR_BRIDGE_DIR 'Feir-Interface.ps1') -Raw)))
    $showSettings = {
        $form.Show()
        if ($form.WindowState -eq 'Minimized') { $form.WindowState = 'Normal' }
        $form.Activate()
    }.GetNewClosure()
    $settingsItem = New-Object Windows.Forms.ToolStripMenuItem((& $translate 'Configurar botões'))
    $exitItem.Text = & $translate 'Sair'
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
    $client = [Feir.ViiperServer]::new()
    $mapping = [Nefarius.ViGEm.Client.Targets.DualShock4.DualShock4Buttons]
    $buttonNames = 'Triangle','Circle','Cross','Square','ShoulderLeft','ShoulderRight','TriggerLeft','TriggerRight','Share','Options','ThumbLeft','ThumbRight'
    [int[]]$masks = @($buttonNames | ForEach-Object { [int][Enum]::Parse($mapping, $_) })


    function Show-FeirDevices($devices) {
        $lines = foreach ($device in $devices) {
            $id = $device.ProductGuid.ToString('N').Substring(0, 8)
            $name = $device.InstanceName.Trim()
            if ($id -eq '09cc054c') {
                # O mesmo ID também pode pertencer a um DualShock 4 físico.
                $probe = $null
                try {
                    $probe = [SharpDX.DirectInput.Joystick]::new($inputApi, $device.InstanceGuid)
                    if ([Feir.DeviceOrigin]::IsUsbIp($probe.Properties.InterfacePath)) { continue }
                } catch {} finally { if ($probe) { $probe.Dispose() } }
            }
            $support = if ($id -eq '00010810') {
                & $translate 'Compatível com o Feir Controll'
            } else { & $translate 'Detectado. Remapeamento indisponível neste modelo.' }
            '{0}  ·  {1}:{2}' -f $name, $id.Substring(4).ToUpperInvariant(), $id.Substring(0,4).ToUpperInvariant()
            "    $support"
            ''
        }
        if (-not $lines) { $lines = @((& $translate 'Nenhum controle físico foi encontrado.')) }
        if ($session.DetectionWindow -and -not $session.DetectionWindow.IsDisposed) {
            $session.DetectionWindow.Close()
        }
        $dialog = [Feir.SignalForm]::new()
        $dialog.Text = & $translate 'Controles detectados'
        $dialog.Icon = $form.Icon
        $dialog.BackColor = $form.BackColor
        $dialog.ForeColor = $form.ForeColor
        $dialog.ClientSize = [Drawing.Size]::new(510, 250)
        $dialog.FormBorderStyle = 'FixedDialog'
        $dialog.MaximizeBox = $false
        $dialog.MinimizeBox = $false
        $dialog.ShowInTaskbar = $false
        $dialog.StartPosition = 'CenterParent'
        $box = New-Object Windows.Forms.TextBox
        $box.SetBounds(18, 18, 474, 214)
        $box.Multiline = $true
        $box.ReadOnly = $true
        $box.ScrollBars = 'Vertical'
        $box.BorderStyle = 'None'
        $box.Font = [Drawing.Font]::new('Segoe UI', 11)
        $box.BackColor = $form.BackColor
        $box.ForeColor = $form.ForeColor
        $box.Text = ($lines -join [Environment]::NewLine).TrimEnd()
        $dialog.Controls.Add($box)
        $session.DetectionWindow = $dialog
        $hint.Text = & $translate 'Controles detectados'
        $dialog.Show($form)
    }

    function Show-FeirControllerPreview {
        if ($session.PreviewWindow -and -not $session.PreviewWindow.IsDisposed) {
            $session.PreviewWindow.Close()
        }

        $session.PreviewSlot = $session.Selected
        $slotName = if ($session.PreviewSlot -eq 0) { 'Controle 1' } else { 'Controle 2' }
        $dialog = [Feir.SignalForm]::new()
        $dialog.Text = (& $translate 'Testar controle') + ' · ' + (& $translate $slotName)
        $dialog.Icon = $form.Icon
        $dialog.BackColor = $form.BackColor
        $dialog.ForeColor = $form.ForeColor
        $dialog.ClientSize = [Drawing.Size]::new(590, 394)
        $dialog.AutoScaleMode = 'Dpi'
        $dialog.AutoScaleDimensions = [Drawing.SizeF]::new(96, 96)
        $dialog.MinimumSize = [Drawing.Size]::new(485, 365)
        $dialog.StartPosition = 'CenterParent'
        $dialog.ShowInTaskbar = $false

        $view = [Feir.ControllerPreview]::new([int[]]$masks)
        $view.SetBounds(15, 37, 560, 310)
        $view.Anchor = 'Top, Bottom, Left, Right'
        $view.BackColor = $dialog.BackColor
        $view.ForeColor = $dialog.ForeColor
        $view.AccessibleName = & $translate 'Testar controle'
        $dialog.Controls.Add($view)

        $connection = [Feir.FeirLabel]::new()
        $connection.SetBounds(20, 8, 550, 26)
        $connection.ForeColor = $dialog.ForeColor
        $dialog.Controls.Add($connection)

        $note = [Feir.FeirLabel]::new()
        $note.SetBounds(20, 351, 550, 28)
        $note.Anchor = 'Bottom, Left, Right'
        $note.ForeColor = $dialog.ForeColor
        $note.Text = & $translate 'Mostra a saída do DualShock 4 com o mapeamento salvo.'
        $dialog.Controls.Add($note)

        $session.PreviewWindow = $dialog
        $session.PreviewView = $view
        $session.PreviewConnection = $connection
        $dialog.Show($form)
    }

    function Update-FeirControllerPreview {
        $slot = $session.Slots[$session.PreviewSlot]
        $label = if ($slot.Connected) { '●  Conectado' } else { '○  Desconectado' }
        $caption = & $translate $label
        if ($session.PreviewConnection.Text -ne $caption) { $session.PreviewConnection.Text = $caption }
        if ($slot.Connected) {
            $report = $slot.Report
            $session.PreviewView.ShowReport($report.Buttons, $report.LeftThumbX, $report.LeftThumbY,
                $report.RightThumbX, $report.RightThumbY)
        } else {
            $session.PreviewView.ShowReport(8, 128, 128, 128, 128)
        }
    }

    $scanAt = 0
    $paintAt = 0
    $clock = [Diagnostics.Stopwatch]::StartNew()
    while ($session.Running) {
        Update-FeirWindow
        if (-not $session.Running) { break }
        if ($session.PreviewRequested) {
            $session.PreviewRequested = $false
            Show-FeirControllerPreview
        }
        $now = $clock.ElapsedMilliseconds
        if ($now -ge $scanAt -or $session.ScanRequested) {
            $scanAt = $now + 900
            $attached = @($inputApi.GetDevices([SharpDX.DirectInput.DeviceClass]::GameControl, [SharpDX.DirectInput.DeviceEnumerationFlags]::AttachedOnly))
            if ($session.ScanRequested) {
                $session.ScanRequested = $false
                try { Show-FeirDevices $attached }
                catch { $hint.Text = & $translate 'Não foi possível detectar os controles.' }
            }
            $devices = @($attached | Where-Object { $_.ProductGuid -like '00010810-*' } | Sort-Object InstanceGuid)
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
                    $slot.Target = $client.Create()
                    try { $slot.Rumble = [Feir.Rumble]::Open($slot.Joystick.Properties.InterfacePath, $null) }
                    catch {
                        $slot.Rumble = $null
                        if ($env:FEIR_RUMBLE_DIAGNOSTICS) {
                            [IO.File]::AppendAllText($env:FEIR_RUMBLE_DIAGNOSTICS, "Rumble initialization failed: $($_.Exception.GetBaseException().Message)`r`n")
                        }
                    }
                    if ($env:FEIR_RUMBLE_DIAGNOSTICS) {
                        [IO.File]::AppendAllText($env:FEIR_RUMBLE_DIAGNOSTICS, "Rumble attached: $($null -ne $slot.Rumble), enabled: $($slot.RumbleEnabled)`r`n")
                    }
                    $slot.Target.Motor = $slot.Rumble
                    $slot.Report = [Nefarius.ViGEm.Client.Targets.DualShock4.DualShock4Report]::new()
                    $slot.LastEffectCount = 0
                    $slot.Connected = $true
                } catch { Close-FeirSlot $slot; throw }
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
            $inputState = $slot.PendingInput
            $pov = $state.PointOfViewControllers
            $slot.DigitalDpad = [Feir.DirectionalPad]::IsDigitalMode($state.X, $state.Y, $state.Z,
                $state.RotationZ, $pov, $slot.DigitalDpad)
            [Feir.DirectionalPad]::Read($state.Buttons, $pov, $inputState)
            if ($slot.DigitalDpad) { [Feir.DirectionalPad]::ReadDigitalAxes($state.X, $state.Y, $inputState) }
            if ($slotIndex -eq $session.Selected -and $session.LearnIndex -ge 0) {
                for ($i = 0; $i -lt $inputState.Length; $i++) {
                    if ($inputState[$i] -and -not $slot.Input[$i]) {
                        $row = $session.LearnIndex
                        $session.LearnIndex = -1
                        $slot.Draft[$row] = $i
                        $list.Items[$row].SubItems[1].Text = $session.InputNames[$i + 1]
                        $session.UpdatingPicker = $true
                        $picker.SelectedIndex = $i + 1
                        $session.UpdatingPicker = $false
                        $hint.Text = & $translate 'Botão detectado. Clique em Salvar mapeamento.'
                        break
                    }
                }
            }
            $slot.PendingInput = $slot.Input
            $slot.Input = $inputState
            $buttons = [Feir.DirectionalPad]::MapReport($inputState, $slot.Map, $masks)
            $report = $slot.Report
            $report.Buttons = [uint16]$buttons
            $report.LeftThumbX = if ($slot.DigitalDpad) { [byte]128 } else { [byte]($state.X -shr 8) }
            $report.LeftThumbY = if ($slot.DigitalDpad) { [byte]128 } else { [byte]($state.Y -shr 8) }
            $report.RightThumbX = if ($slot.DigitalDpad) { [byte]128 } else { [byte]($state.RotationZ -shr 8) }
            $report.RightThumbY = if ($slot.DigitalDpad) { [byte]128 } else { [byte]($state.Z -shr 8) }
            $report.LeftTrigger = [byte](255 * [int](0 -ne ($buttons -band $masks[6])))
            $report.RightTrigger = [byte](255 * [int](0 -ne ($buttons -band $masks[7])))
            try { $slot.Target.SendReport($report) } catch { Close-FeirSlot $slot }
            if ($slot.Rumble -and -not $slot.Rumble.Update($slot.RumbleEnabled, $slot.RumbleGain)) {
                if ($env:FEIR_RUMBLE_DIAGNOSTICS) {
                    [IO.File]::AppendAllText($env:FEIR_RUMBLE_DIAGNOSTICS, "Physical vibration command rejected.`r`n")
                }
                $slot.Rumble.Dispose()
                $slot.Rumble = $null
                if ($slotIndex -eq $session.Selected) { $hint.Text = & $translate 'O controle não aceitou o comando de vibração.' }
            }
        }
        if ($now -ge $paintAt) {
            if ($env:FEIR_RUMBLE_DIAGNOSTICS) {
                foreach ($slot in $session.Slots) {
                    if ($slot.Rumble -and $slot.Rumble.ReceivedEffects -gt 0 -and $slot.Rumble.ReceivedEffects -ne $slot.LastEffectCount) {
                        $slot.LastEffectCount = $slot.Rumble.ReceivedEffects
                        [IO.File]::AppendAllText($env:FEIR_RUMBLE_DIAGNOSTICS, "$(Get-Date -Format HH:mm:ss) effects=$($slot.LastEffectCount) motors=$($slot.Rumble.LastSent) enabled=$($slot.RumbleEnabled)`r`n")
                    }
                }
            }
            $paintAt = $now + 32
            $connected = @($session.Slots | Where-Object Connected -eq $true).Count
            $trayText = 'Feir Controll | ' + ((& $translate '{0} de 2 conectados') -f $connected)
            if ($renderedLanguage -ne $session.Language) {
                $renderedLanguage = $session.Language
                $settingsItem.Text = & $translate 'Configurar botões'
                $exitItem.Text = & $translate 'Sair'
            }
            if ($tray.Text -ne $trayText) { $tray.Text = $trayText }
            if ($form.Visible) { Update-FeirStatus }
            if ($session.PreviewWindow -and -not $session.PreviewWindow.IsDisposed -and $session.PreviewWindow.Visible) {
                Update-FeirControllerPreview
            }
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

























