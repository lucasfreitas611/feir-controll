$localePath = Join-Path $env:FEIR_BRIDGE_DIR 'feir-controll-idioma.txt'
$translations = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText((Join-Path $env:FEIR_BRIDGE_DIR 'FeirControll-Languages.json')))
$languageCodes = @('pt','en','es')
$session.Language = 'pt'
if (Test-Path -LiteralPath $localePath) {
    try {
        $savedLanguage = [IO.File]::ReadAllText($localePath).Trim()
        if ($savedLanguage -in $languageCodes) { $session.Language = $savedLanguage }
    } catch {}
}
$translate = {
    param([string]$text)
    $language = $translations.PSObject.Properties[$session.Language]
    if ($language) {
        $entry = $language.Value.PSObject.Properties[$text]
        if ($entry) { return [string]$entry.Value }
    }
    return $text
}.GetNewClosure()

function New-FeirSurface($left, $top, $width, $height, $color) {
    $surface = [Feir.RoundedPanel]::new()
    $surface.SetBounds($left, $top, $width, $height)
    $surface.BackColor = [Drawing.ColorTranslator]::FromHtml($color)
    $form.Controls.Add($surface)
    return $surface
}


function New-FeirLabel($text, $left, $top, $width, $height, $color, $size) {
    $label = [Feir.FeirLabel]::new()
    $label.Text = $text
    $label.SetBounds($left, $top, $width, $height)
    $label.ForeColor = [Drawing.ColorTranslator]::FromHtml($color)
    $label.Font = [Drawing.Font]::new('Segoe UI', $size)
    $form.Controls.Add($label)
    return $label
}
function New-FeirButton($text, $left, $top, $width, $background) {
    $button = [Feir.RoundedButton]::new()
    $button.Text = $text
    $button.SetBounds($left, $top, $width, 40)
    $button.FlatStyle = 'Flat'
    $button.FlatAppearance.BorderSize = 0
    $button.FlatAppearance.MouseOverBackColor = [Drawing.ColorTranslator]::FromHtml('#28523D')
    $button.FlatAppearance.MouseDownBackColor = [Drawing.ColorTranslator]::FromHtml('#237553')
    $button.Cursor = [Windows.Forms.Cursors]::Hand
    $button.Font = [Drawing.Font]::new('Segoe UI Semibold', 9.5)
    $button.BackColor = [Drawing.ColorTranslator]::FromHtml($background)
    $button.UseVisualStyleBackColor = $false
    $form.Controls.Add($button)
    return $button
}

[Windows.Forms.Application]::EnableVisualStyles()
$form = [Feir.SignalForm]::new()
$form.Text = 'Feir Controll'
$form.ClientSize = [Drawing.Size]::new(870, 650)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.AutoScaleMode = 'Dpi'
$form.Icon = [Drawing.Icon]::new((Join-Path $env:FEIR_BRIDGE_DIR 'Feir-Controll.ico'), 48, 48)
$windowIcon = $form.Icon
$form.add_Disposed({ $windowIcon.Dispose() }.GetNewClosure())
$form.BackColor = [Drawing.ColorTranslator]::FromHtml('#0A100D')
$form.ForeColor = [Drawing.ColorTranslator]::FromHtml('#ECF5EF')
$form.Font = [Drawing.Font]::new('Segoe UI', 10)

$banner = [Feir.SignalBanner]::new()
$banner.SetBounds(24, 16, 832, 86)
$form.Controls.Add($banner)
$brand = New-FeirLabel 'FEIR CONTROLL' 0 0 380 41 '#E2FFEC' 25
$brand.Font = [Drawing.Font]::new('Segoe UI Semibold', 25)
$brand.BackColor = [Drawing.Color]::Transparent
$banner.Controls.Add($brand)
$brand.Location = [Drawing.Point]::new(22, 8)
$status = New-FeirLabel 'Controle USB  /  DualShock 4 virtual' 0 0 385 24 '#A2E8BE' 10
$status.Font = [Drawing.Font]::new('Consolas', 10)
$status.BackColor = [Drawing.Color]::Transparent
$banner.Controls.Add($status)
$status.Location = [Drawing.Point]::new(25, 53)
$mappingTitle = New-FeirLabel 'Mapeamento de botões' 264 104 350 30 '#ECF5EF' 15

$slotOne = New-FeirButton 'Controle 1' 40 163 174 '#176044'
$slotTwo = New-FeirButton 'Controle 2' 40 255 174 '#1B3027'
$slotOneStatus = New-FeirLabel '○  Desconectado' 50 209 155 24 '#9AB2A6' 10
$slotTwoStatus = New-FeirLabel '○  Desconectado' 50 301 155 24 '#9AB2A6' 10
$section = New-FeirLabel 'Controles' 42 126 168 28 '#E2E8F0' 11
foreach ($label in @($section,$slotOneStatus,$slotTwoStatus)) { $label.BackColor = [Drawing.ColorTranslator]::FromHtml('#131F19') }
$sidebar = New-FeirSurface 24 115 206 230 '#131F19'
foreach ($control in @($section,$slotOne,$slotTwo,$slotOneStatus,$slotTwoStatus)) {
    $control.Location = [Drawing.Point]::new(($control.Left - $sidebar.Left), ($control.Top - $sidebar.Top))
    $sidebar.Controls.Add($control)
}
$slotStatus = @($slotOneStatus,$slotTwoStatus)
$slotButtons = @($slotOne,$slotTwo)
$session.Selected = 0
$list = [Feir.SignalList]::new()
$buffer = $list.GetType().GetProperty("DoubleBuffered", [Reflection.BindingFlags]"Instance, NonPublic")
$buffer.SetValue($list, $true, $null)
$list.SetBounds(264, 183, 580, 296)
$list.View = 'Details'
$list.HeaderStyle = 'None'
$list.FullRowSelect = $true
$list.MultiSelect = $false
$list.HideSelection = $false
$list.BorderStyle = 'None'
$list.BackColor = [Drawing.ColorTranslator]::FromHtml('#131F19')
$list.ForeColor = $form.ForeColor
$null = $list.Columns.Add('Função no PlayStation', 203)
$null = $list.Columns.Add('Botão físico do Feir', 230)
$null = $list.Columns.Add('Entrada', 125)
$form.Controls.Add($list)
$headings = @(
    (New-FeirLabel 'Função no PlayStation' 276 155 188 24 '#ABC9BA' 9)
    (New-FeirLabel 'Botão físico do Feir' 472 155 215 24 '#ABC9BA' 9)
    (New-FeirLabel 'Entrada' 701 155 128 24 '#ABC9BA' 9)
)
foreach ($heading in $headings) { $heading.BackColor = [Drawing.ColorTranslator]::FromHtml('#131F19') }
$table = New-FeirSurface 252 146 604 341 '#131F19'
foreach ($control in @($headings) + @($list)) {
    $control.Location = [Drawing.Point]::new(($control.Left - $table.Left), ($control.Top - $table.Top))
    $table.Controls.Add($control)
}

$buttonIcons = New-Object Windows.Forms.ImageList
$buttonIcons.ColorDepth = 'Depth32Bit'
$buttonIcons.ImageSize = [Drawing.Size]::new(26, 22)
$colors = '#68D7AD','#FF858A','#83ADFF','#EAA9E9'
$badges = 'L1','R1','L2','R2','↖','≡','L3','R3'
$iconFont = [Drawing.Font]::new('Segoe UI', 10, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
$alignment = New-Object Drawing.StringFormat
$alignment.Alignment = 'Center'
$alignment.LineAlignment = 'Center'
foreach ($index in 0..11) {
    $bitmap = New-Object Drawing.Bitmap(26, 22)
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = 'AntiAlias'
    $graphics.TextRenderingHint = 'AntiAliasGridFit'
    $tint = if ($index -lt 4) { $colors[$index] } else { '#97B0D3' }
    $pen = [Drawing.Pen]::new([Drawing.ColorTranslator]::FromHtml($tint), 1.7)
    try {
        switch ($index) {
            0 { $graphics.DrawPolygon($pen, [Drawing.Point[]]@([Drawing.Point]::new(13,4),[Drawing.Point]::new(20,17),[Drawing.Point]::new(6,17))) }
            1 { $graphics.DrawEllipse($pen, 6, 4, 14, 14) }
            2 { $graphics.DrawLine($pen, 7, 5, 19, 17); $graphics.DrawLine($pen, 19, 5, 7, 17) }
            3 { $graphics.DrawRectangle($pen, 7, 5, 12, 12) }
            default {
                $graphics.DrawRectangle($pen, 3, 4, 20, 14)
                $bounds = [Drawing.RectangleF]::new(3, 4, 20, 14)
                $graphics.DrawString($badges[$index - 4], $iconFont, $pen.Brush, $bounds, $alignment)
            }
        }
        $null = $buttonIcons.Images.Add($bitmap)
    } finally {
        $pen.Dispose()
        $graphics.Dispose()
    }
}
$alignment.Dispose()
$iconFont.Dispose()
$list.SmallImageList = $buttonIcons
$form.add_Disposed({ $buttonIcons.Dispose() }.GetNewClosure())


$names = @('Triângulo','Círculo','Cruz (×)','Quadrado','L1','R1','L2','R2','Share (Select)','Options (Start)','L3','R3')
$baseInputs = @('Desativado','Triângulo [1]','Círculo [2]','Cruz [3]','Quadrado [4]','L1 [5]','R1 [6]','L2 [7]','R2 [8]','Select [9]','Start [10]','L3 [11]','R3 [12]')
$session.InputNames = $baseInputs
$session.Slots = @(
    @{ Path = (Join-Path $env:FEIR_BRIDGE_DIR 'perfil-feir.json'); Connected = $false; Input = [bool[]]::new(12) }
    @{ Path = (Join-Path $env:FEIR_BRIDGE_DIR 'perfil-feir-2.json'); Connected = $false; Input = [bool[]]::new(12) }
)
foreach ($slot in $session.Slots) {
    $slot.Map = [int[]](0..11)
    if (Test-Path -LiteralPath $slot.Path) {
        try {
            $loaded = ConvertFrom-Json -InputObject (Get-Content -LiteralPath $slot.Path -Raw)
            if ($loaded.Count -ne 12 -or @($loaded | Where-Object { $_ -isnot [int] -or $_ -lt -1 -or $_ -gt 11 }).Count) {
                throw 'Mapeamento inválido'
            }
            $slot.Map = [int[]]$loaded
        } catch { $status.Text = & $translate 'Perfil inválido. Padrão carregado.' }
    }
    $slot.Draft = [int[]]$slot.Map.Clone()
}
foreach ($index in 0..11) {
    $row = $list.Items.Add($names[$index], $index)
    $null = $row.SubItems.Add($session.InputNames[1 + $session.Slots[$session.Selected].Draft[$index]])
    $null = $row.SubItems.Add("—")
}
$picker = [Feir.SignalCombo]::new()
$picker.SetBounds(264, 499, 263, 32)
$picker.FlatStyle = 'Flat'
$picker.BackColor = [Drawing.ColorTranslator]::FromHtml('#1A2922')
$picker.ForeColor = $form.ForeColor
$picker.Items.AddRange([object[]]$session.InputNames)
$form.Controls.Add($picker)
$learn = New-FeirButton 'Detectar botão' 541 493 140 '#1A2922'
$reset = New-FeirButton 'Restaurar padrão' 695 493 149 '#1A2922'
$hint = New-FeirLabel 'O direcional e os analógicos seguem o mapeamento original.' 264 546 580 30 '#C0D7CA' 9
$save = New-FeirButton 'Salvar mapeamento' 657 589 187 '#176044'
$hide = New-FeirButton 'Ocultar janela' 24 589 206 '#1A2922'




$vibration = New-FeirButton 'Testar vibração' 24 412 206 '#1A2922'
$rumbleToggle = New-Object Windows.Forms.CheckBox
$rumbleToggle.Text = 'Vibração nos jogos'
$rumbleToggle.SetBounds(32, 380, 198, 27)
$rumbleToggle.FlatStyle = 'Flat'
$rumbleToggle.Cursor = [Windows.Forms.Cursors]::Hand
$form.Controls.Add($rumbleToggle)
$session.UpdatingRumble = $false
foreach ($slot in $session.Slots) {
    $slot.RumbleEnabled = $true
    $slot.RumbleSetting = [IO.Path]::ChangeExtension($slot.Path, '.rumble')
    if (Test-Path -LiteralPath $slot.RumbleSetting) {
        $slot.RumbleEnabled = ([IO.File]::ReadAllText($slot.RumbleSetting).Trim() -ne 'off')
    }
}
$rumbleToggle.add_CheckedChanged({
    if ($session.UpdatingRumble) { return }
    $slot = $session.Slots[$session.Selected]
    try {
        [IO.File]::WriteAllText($slot.RumbleSetting, $(if ($rumbleToggle.Checked) { 'on' } else { 'off' }))
        $slot.RumbleEnabled = $rumbleToggle.Checked
    } catch {
        $session.UpdatingRumble = $true
        $rumbleToggle.Checked = $slot.RumbleEnabled
        $session.UpdatingRumble = $false
        $hint.Text = & $translate 'Não foi possível salvar a configuração de vibração.'
    }
}.GetNewClosure())
$vibration.add_Click({
    $slot = $session.Slots[$session.Selected]
    if ($slot.Rumble) {
        $slot.Rumble.Test()
        $hint.Text = & $translate 'Pulso de teste enviado ao controle selecionado.'
    } else {
        $hint.Text = & $translate 'Vibração indisponível no controle selecionado.'
    }
}.GetNewClosure())


$gainLabel = New-FeirLabel 'Intensidade nos jogos' 32 459 192 23 '#C0D7CA' 9
$rumbleGain = [Feir.SignalCombo]::new()
$rumbleGain.SetBounds(32, 484, 190, 28)
$rumbleGain.FlatStyle = 'Flat'
$rumbleGain.BackColor = [Drawing.ColorTranslator]::FromHtml('#1A2922')
$rumbleGain.ForeColor = $form.ForeColor
$baseGains = @('Original · 100%','Reforçada · 160%','Forte · 200%')
$rumbleGain.Items.AddRange([object[]]$baseGains)
$form.Controls.Add($rumbleGain)
$gainValues = @(100,160,200)
foreach ($slot in $session.Slots) {
    $slot.RumbleGain = 200
    $slot.RumbleGainPath = [IO.Path]::ChangeExtension($slot.Path, '.gain')
    if (Test-Path -LiteralPath $slot.RumbleGainPath) {
        try {
            $value = [int][IO.File]::ReadAllText($slot.RumbleGainPath).Trim()
            if ($value -in $gainValues) { $slot.RumbleGain = $value }
        } catch {}
    }
}
$rumbleGain.add_SelectionChangeCommitted({
    if ($session.UpdatingRumble -or $rumbleGain.SelectedIndex -lt 0) { return }
    $slot = $session.Slots[$session.Selected]
    try {
        $value = $gainValues[$rumbleGain.SelectedIndex]
        [IO.File]::WriteAllText($slot.RumbleGainPath, [string]$value)
        $slot.RumbleGain = $value
        $hint.Text = & $translate 'Intensidade aplicada ao controle selecionado.'
    } catch {
        $session.UpdatingRumble = $true
        $rumbleGain.SelectedIndex = [Array]::IndexOf($gainValues, $slot.RumbleGain)
        $session.UpdatingRumble = $false
        $hint.Text = & $translate 'Não foi possível salvar a intensidade.'
    }
}.GetNewClosure())

function Set-FeirStartup($path, $launcher, $enabled) {
    if ($enabled) {
        $shell = New-Object -ComObject WScript.Shell
        $entry = $shell.CreateShortcut($path)
        $entry.TargetPath = $launcher
        $entry.Arguments = '--background'
        $entry.WorkingDirectory = Split-Path -Parent $launcher
        $entry.Description = 'Inicializa o Feir Controll na bandeja'
        $entry.Save()
    } elseif ([IO.File]::Exists($path)) {
        [IO.File]::Delete($path)
    }
}

$startup = New-Object Windows.Forms.CheckBox
$startup.Text = 'Iniciar com o Windows'
$startup.SetBounds(32, 350, 198, 27)
$startup.Cursor = [Windows.Forms.Cursors]::Hand
$startup.FlatStyle = 'Flat'
$startup.ForeColor = [Drawing.ColorTranslator]::FromHtml('#ECF5EF')
$startup.FlatAppearance.CheckedBackColor = [Drawing.ColorTranslator]::FromHtml('#176044')
$startup.FlatAppearance.MouseOverBackColor = [Drawing.ColorTranslator]::FromHtml('#1B3027')
$startupFolder = [Environment]::GetFolderPath('Startup')
$startupPath = Join-Path $startupFolder 'Feir Controller - Bandeja.lnk'
$launcherPath = Join-Path $env:FEIR_BRIDGE_DIR 'Feir Controll.exe'
$startup.Checked = [IO.File]::Exists($startupPath)
$form.Controls.Add($startup)
$setStartup = (Get-Command Set-FeirStartup).ScriptBlock
$startupState = @{ Updating = $false }
$startup.add_CheckedChanged({
    if ($startupState.Updating) { return }
    try {
        & $setStartup $startupPath $launcherPath $startup.Checked
        $hint.Text = if ($startup.Checked) {
            & $translate 'O Feir Controll vai iniciar na bandeja ao entrar no Windows.'
        } else {
            & $translate 'Inicialização automática desativada.'
        }
    } catch {
        $startupState.Updating = $true
        $startup.Checked = [IO.File]::Exists($startupPath)
        $startupState.Updating = $false
        $hint.Text = (& $translate 'Não foi possível atualizar a inicialização.') + " $($_.Exception.Message)"
    }
}.GetNewClosure())

$session.LearnIndex = -1
$session.UpdatingPicker = $false

$list.add_SelectedIndexChanged({
    $session.LearnIndex = -1
    if ($list.SelectedIndices.Count -eq 1) {
        $session.UpdatingPicker = $true
        $picker.SelectedIndex = $session.Slots[$session.Selected].Draft[$list.SelectedIndices[0]] + 1
        $session.UpdatingPicker = $false
    }
}.GetNewClosure())
$picker.add_SelectionChangeCommitted({
    if (-not $session.UpdatingPicker -and $list.SelectedIndices.Count -eq 1 -and $picker.SelectedIndex -ge 0) {
        $session.LearnIndex = -1
        $index = $list.SelectedIndices[0]
        $session.Slots[$session.Selected].Draft[$index] = $picker.SelectedIndex - 1
        $list.Items[$index].SubItems[1].Text = [string]$picker.SelectedItem
        $hint.Text = & $translate 'Alteração pendente. Clique em Salvar mapeamento.'
    }
}.GetNewClosure())
$learn.add_Click({
    if (-not $session.Slots[$session.Selected].Connected) { $hint.Text = & $translate 'Conecte o controle Feir para detectar um botão.'; return }
    if ($list.SelectedIndices.Count -ne 1) { return }
    $session.LearnIndex = $list.SelectedIndices[0]
    $hint.Text = & $translate 'Pressione um botão físico do Feir…'
}.GetNewClosure())
$reset.add_Click({
    $session.LearnIndex = -1
    foreach ($index in 0..11) {
        $session.Slots[$session.Selected].Draft[$index] = $index
        $list.Items[$index].SubItems[1].Text = $session.InputNames[$index + 1]
    }
    if ($list.SelectedIndices.Count -eq 1) {
        $session.UpdatingPicker = $true
        $picker.SelectedIndex = $list.SelectedIndices[0] + 1
        $session.UpdatingPicker = $false
    }
    $hint.Text = & $translate 'Padrão restaurado. Clique em Salvar mapeamento.'
}.GetNewClosure())
$save.add_Click({
    $profilePath = $session.Slots[$session.Selected].Path
    $temp = "$profilePath.tmp"
    try {
        $json = ConvertTo-Json -InputObject $session.Slots[$session.Selected].Draft -Compress
        [IO.File]::WriteAllText($temp, $json)
        if ([IO.File]::Exists($profilePath)) { [IO.File]::Replace($temp, $profilePath, "$profilePath.bak") }
        else { [IO.File]::Move($temp, $profilePath) }
        $session.Slots[$session.Selected].Map = [int[]]$session.Slots[$session.Selected].Draft.Clone()
        $session.LearnIndex = -1
        $hint.Text = & $translate 'Mapeamento salvo e aplicado.'
    } catch {
        $hint.Text = (& $translate 'Não foi possível salvar.') + " $($_.Exception.Message)"
    } finally {
        if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) }
        if ([IO.File]::Exists("$profilePath.bak")) { [IO.File]::Delete("$profilePath.bak") }
    }
}.GetNewClosure())
$hide.add_Click({ $form.Hide() }.GetNewClosure())
$form.add_FormClosing({
    param($sender, $event)
    if ($session.Running -and $event.CloseReason -eq 'UserClosing') {
        $event.Cancel = $true
        $form.Hide()
    }
}.GetNewClosure())
$list.Items[0].Selected = $true
$picker.SelectedIndex = $session.Slots[$session.Selected].Draft[0] + 1




$syncRumbleControls = {
    $slot = $session.Slots[$session.Selected]
    $session.UpdatingRumble = $true
    try {
        $rumbleToggle.Checked = $slot.RumbleEnabled
        $rumbleGain.SelectedIndex = [Array]::IndexOf($gainValues, $slot.RumbleGain)
    } finally {
        $session.UpdatingRumble = $false
    }
}.GetNewClosure()
& $syncRumbleControls

foreach ($slotIndex in 0..1) {
    $slotButtons[$slotIndex].add_Click({
        $session.Selected = $slotIndex
        & $syncRumbleControls
        $session.LearnIndex = -1
        $slot = $session.Slots[$slotIndex]
        foreach ($index in 0..11) {
            $list.Items[$index].SubItems[1].Text = $session.InputNames[1 + $slot.Draft[$index]]
        }
        foreach ($i in 0..1) {
            $color = if ($i -eq $slotIndex) { '#176044' } else { '#1B3027' }
            $slotButtons[$i].BackColor = [Drawing.ColorTranslator]::FromHtml($color)
        }
        if ($list.SelectedIndices.Count -eq 1) {
            $session.UpdatingPicker = $true
            $picker.SelectedIndex = 1 + $slot.Draft[$list.SelectedIndices[0]]
            $session.UpdatingPicker = $false
        }
        $hint.Text = if (($slot.Draft -join ',') -eq ($slot.Map -join ',')) {
            & $translate 'Os botões pressionados aparecem em tempo real.'
        } else { & $translate 'Alteração pendente. Clique em Salvar mapeamento.' }
    }.GetNewClosure())
}


$languageLabel = New-FeirLabel 'Idioma' 618 112 70 24 '#ABC9BA' 9
$language = [Feir.SignalCombo]::new()
$language.SetBounds(692, 108, 152, 27)
$language.BackColor = [Drawing.ColorTranslator]::FromHtml('#1A2922')
$language.ForeColor = $form.ForeColor
$language.Items.AddRange([object[]]@('Português','English','Español'))
$language.SelectedIndex = [Array]::IndexOf($languageCodes, $session.Language)
$form.Controls.Add($language)
$detect = New-FeirButton 'Detectar controles' 24 525 206 '#1A2922'
$detect.add_Click({
    $session.ScanRequested = $true
    $hint.Text = & $translate 'Aguardando leitura dos dispositivos…'
}.GetNewClosure())
$captions = @(
    @{ Control = $status; Text = 'Controle USB  /  DualShock 4 virtual' }
    @{ Control = $mappingTitle; Text = 'Mapeamento de botões' }
    @{ Control = $section; Text = 'Controles' }
    @{ Control = $slotOne; Text = 'Controle 1' }
    @{ Control = $slotTwo; Text = 'Controle 2' }
    @{ Control = $headings[0]; Text = 'Função no PlayStation' }
    @{ Control = $headings[1]; Text = 'Botão físico do Feir' }
    @{ Control = $headings[2]; Text = 'Entrada' }
    @{ Control = $learn; Text = 'Detectar botão' }
    @{ Control = $reset; Text = 'Restaurar padrão' }
    @{ Control = $save; Text = 'Salvar mapeamento' }
    @{ Control = $hide; Text = 'Ocultar janela' }
    @{ Control = $vibration; Text = 'Testar vibração' }
    @{ Control = $rumbleToggle; Text = 'Vibração nos jogos' }
    @{ Control = $startup; Text = 'Iniciar com o Windows' }
    @{ Control = $gainLabel; Text = 'Intensidade nos jogos' }
    @{ Control = $languageLabel; Text = 'Idioma' }
    @{ Control = $detect; Text = 'Detectar controles' }
)
$applyLanguage = {
    foreach ($caption in $captions) { $caption.Control.Text = & $translate $caption.Text }
    for ($i = 0; $i -lt $headings.Count; $i++) { $list.Columns[$i].Text = $headings[$i].Text }
    $session.InputNames = @($baseInputs | ForEach-Object { & $translate $_ })
    $picker.Items.Clear()
    $picker.Items.AddRange([object[]]$session.InputNames)
    $rumbleGain.Items.Clear()
    $rumbleGain.Items.AddRange([object[]]@($baseGains | ForEach-Object { & $translate $_ }))
    $slot = $session.Slots[$session.Selected]
    $rumbleGain.SelectedIndex = [Array]::IndexOf($gainValues, $slot.RumbleGain)
    $picker.SelectedIndex = if ($list.SelectedIndices.Count -eq 1) { 1 + $slot.Draft[$list.SelectedIndices[0]] } else { -1 }
    $picker.RefreshOptions()
    $rumbleGain.RefreshOptions()
    $picker.AccessibleName = & $translate 'Botão físico do Feir'
    $rumbleGain.AccessibleName = & $translate 'Intensidade nos jogos'
    $language.AccessibleName = & $translate 'Idioma'
    for ($i = 0; $i -lt $names.Count; $i++) {
        $list.Items[$i].Text = & $translate $names[$i]
        $list.Items[$i].SubItems[1].Text = $session.InputNames[1 + $slot.Draft[$i]]
    }
    $hint.Text = & $translate $(if (($slot.Draft -join ',') -eq ($slot.Map -join ',')) {
        'O direcional e os analógicos seguem o mapeamento original.'
    } else { 'Alteração pendente. Clique em Salvar mapeamento.' })
}.GetNewClosure()
& $applyLanguage
$language.add_SelectionChangeCommitted({
    try {
        $code = $languageCodes[$language.SelectedIndex]
        [IO.File]::WriteAllText($localePath, $code)
        $session.Language = $code
        & $applyLanguage
    } catch {
        $language.SelectedIndex = [Array]::IndexOf($languageCodes, $session.Language)
        $hint.Text = & $translate 'Não foi possível salvar o idioma.'
    }
}.GetNewClosure())

$connectedColor = [Drawing.ColorTranslator]::FromHtml('#6EE7B7')
$disconnectedColor = [Drawing.ColorTranslator]::FromHtml('#9AB2A6')
$pressedColor = [Drawing.ColorTranslator]::FromHtml('#23543D')
$rowColors = @(
    [Drawing.ColorTranslator]::FromHtml('#131F19')
    [Drawing.ColorTranslator]::FromHtml('#17261E')
)
function Update-FeirStatus {
    foreach ($i in 0..1) {
        $label = $slotStatus[$i]
        $connected = $session.Slots[$i].Connected
        $text = if ($connected) { & $translate '●  Conectado' } else { & $translate '○  Desconectado' }
        if ($label.Text -ne $text) {
            $label.Text = $text
            $label.ForeColor = if ($connected) { $connectedColor } else { $disconnectedColor }
        }
    }
    $slot = $session.Slots[$session.Selected]
    $vibration.Enabled = $null -ne $slot.Rumble
    foreach ($i in 0..11) {
        $physical = $slot.Draft[$i]
        $pressed = $slot.Connected -and $physical -ge 0 -and $slot.Input[$physical]
        $row = $list.Items[$i]
        $text = if ($pressed) { & $translate 'Pressionado' } else { '—' }
        $color = if ($pressed) { $pressedColor } else { $rowColors[$i % 2] }
        if ($row.SubItems[2].Text -ne $text) { $row.SubItems[2].Text = $text }
        if ($row.BackColor -ne $color) { $row.BackColor = $color }
    }
}















