function New-FeirSurface($left, $top, $width, $height, $color) {
    $surface = [Feir.RoundedPanel]::new()
    $surface.SetBounds($left, $top, $width, $height)
    $surface.BackColor = [Drawing.ColorTranslator]::FromHtml($color)
    $form.Controls.Add($surface)
    return $surface
}


function New-FeirLabel($text, $left, $top, $width, $height, $color, $size) {
    $label = New-Object Windows.Forms.Label
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
    $button.FlatAppearance.MouseOverBackColor = [Drawing.ColorTranslator]::FromHtml('#384761')
    $button.FlatAppearance.MouseDownBackColor = [Drawing.ColorTranslator]::FromHtml('#304A85')
    $button.Cursor = [Windows.Forms.Cursors]::Hand
    $button.Font = [Drawing.Font]::new('Segoe UI Semibold', 9.5)
    $button.BackColor = [Drawing.ColorTranslator]::FromHtml($background)
    $button.UseVisualStyleBackColor = $false
    $form.Controls.Add($button)
    return $button
}

[Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object Windows.Forms.Form
$form.Text = 'Feir | DualShock 4'
$form.ClientSize = [Drawing.Size]::new(870, 650)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.AutoScaleMode = 'Dpi'
$form.Icon = [Drawing.Icon]::new((Join-Path $env:FEIR_BRIDGE_DIR 'Feir-DualShock4.ico'), 48, 48)
$windowIcon = $form.Icon
$form.add_Disposed({ $windowIcon.Dispose() }.GetNewClosure())
$form.BackColor = [Drawing.ColorTranslator]::FromHtml('#101217')
$form.ForeColor = [Drawing.ColorTranslator]::FromHtml('#F1F5F9')
$form.Font = [Drawing.Font]::new('Segoe UI', 10)
$null = New-FeirLabel 'Feir Controller' 28 17 540 44 '#F8FAFC' 25
$status = New-FeirLabel 'DualShock 4 virtual' 30 64 190 25 '#93C5FD' 10
$null = New-FeirLabel 'Mapeamento de botões' 264 81 550 35 '#F1F5F9' 15

$slotOne = New-FeirButton 'Controle 1' 40 148 174 '#3458B1'
$slotTwo = New-FeirButton 'Controle 2' 40 240 174 '#242C3A'
$slotOneStatus = New-FeirLabel '○  Desconectado' 50 194 155 24 '#94A3B8' 10
$slotTwoStatus = New-FeirLabel '○  Desconectado' 50 286 155 24 '#94A3B8' 10
$section = New-FeirLabel 'Controles' 42 111 168 28 '#E2E8F0' 11
foreach ($label in @($section,$slotOneStatus,$slotTwoStatus)) { $label.BackColor = [Drawing.ColorTranslator]::FromHtml('#191F2B') }
$sidebar = New-FeirSurface 24 100 206 230 '#191F2B'
foreach ($control in @($section,$slotOne,$slotTwo,$slotOneStatus,$slotTwoStatus)) {
    $control.Location = [Drawing.Point]::new(($control.Left - $sidebar.Left), ($control.Top - $sidebar.Top))
    $sidebar.Controls.Add($control)
}
$slotStatus = @($slotOneStatus,$slotTwoStatus)
$slotButtons = @($slotOne,$slotTwo)
$session.Selected = 0
$list = New-Object Windows.Forms.ListView
$buffer = $list.GetType().GetProperty("DoubleBuffered", [Reflection.BindingFlags]"Instance, NonPublic")
$buffer.SetValue($list, $true, $null)
$list.SetBounds(264, 159, 580, 314)
$list.View = 'Details'
$list.HeaderStyle = 'None'
$list.FullRowSelect = $true
$list.MultiSelect = $false
$list.HideSelection = $false
$list.BorderStyle = 'None'
$list.BackColor = [Drawing.ColorTranslator]::FromHtml('#191F2B')
$list.ForeColor = $form.ForeColor
$null = $list.Columns.Add('Função no PlayStation', 203)
$null = $list.Columns.Add('Botão físico do Feir', 230)
$null = $list.Columns.Add('Entrada', 125)
$form.Controls.Add($list)
$headings = @(
    (New-FeirLabel 'Função no PlayStation' 276 130 188 24 '#AAB8CF' 9)
    (New-FeirLabel 'Botão físico do Feir' 472 130 215 24 '#AAB8CF' 9)
    (New-FeirLabel 'Entrada' 701 130 128 24 '#AAB8CF' 9)
)
foreach ($heading in $headings) { $heading.BackColor = [Drawing.ColorTranslator]::FromHtml('#191F2B') }
$table = New-FeirSurface 252 119 604 360 '#191F2B'
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
$inputNames = @('Desativado','Triângulo [1]','Círculo [2]','Cruz [3]','Quadrado [4]','L1 [5]','R1 [6]','L2 [7]','R2 [8]','Select [9]','Start [10]','L3 [11]','R3 [12]')
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
        } catch { $status.Text = 'Perfil inválido. Padrão carregado.' }
    }
    $slot.Draft = [int[]]$slot.Map.Clone()
}
foreach ($index in 0..11) {
    $row = $list.Items.Add($names[$index], $index)
    $null = $row.SubItems.Add($inputNames[1 + $session.Slots[$session.Selected].Draft[$index]])
    $null = $row.SubItems.Add("—")
}
$picker = New-Object Windows.Forms.ComboBox
$picker.SetBounds(264, 499, 263, 32)
$picker.FlatStyle = 'Flat'
$picker.BackColor = [Drawing.ColorTranslator]::FromHtml('#252D3B')
$picker.ForeColor = $form.ForeColor
$picker.DropDownStyle = 'DropDownList'
$picker.Items.AddRange([object[]]$inputNames)
$form.Controls.Add($picker)
$learn = New-FeirButton 'Detectar botão' 541 493 140 '#252D3B'
$reset = New-FeirButton 'Restaurar padrão' 695 493 149 '#252D3B'
$hint = New-FeirLabel 'O direcional e os analógicos seguem o mapeamento original.' 264 546 580 30 '#CBD5E1' 9
$save = New-FeirButton 'Salvar mapeamento' 657 589 187 '#3458B1'
$hide = New-FeirButton 'Ocultar janela' 24 589 206 '#252D3B'


function Set-FeirStartup($path, $launcher, $enabled) {
    if ($enabled) {
        $shell = New-Object -ComObject WScript.Shell
        $entry = $shell.CreateShortcut($path)
        $entry.TargetPath = $launcher
        $entry.Arguments = '--background'
        $entry.WorkingDirectory = Split-Path -Parent $launcher
        $entry.Description = 'Inicializa o Feir Controller na bandeja'
        $entry.Save()
    } elseif ([IO.File]::Exists($path)) {
        [IO.File]::Delete($path)
    }
}

$startup = New-Object Windows.Forms.CheckBox
$startup.Text = 'Iniciar com o Windows'
$startup.SetBounds(32, 347, 198, 30)
$startup.Cursor = [Windows.Forms.Cursors]::Hand
$startup.FlatStyle = 'Flat'
$startup.ForeColor = [Drawing.ColorTranslator]::FromHtml('#F1F5F9')
$startup.FlatAppearance.CheckedBackColor = [Drawing.ColorTranslator]::FromHtml('#3458B1')
$startup.FlatAppearance.MouseOverBackColor = [Drawing.ColorTranslator]::FromHtml('#242C3A')
$startupFolder = [Environment]::GetFolderPath('Startup')
$startupPath = Join-Path $startupFolder 'Feir Controller - Bandeja.lnk'
$launcherPath = Join-Path $env:FEIR_BRIDGE_DIR 'Feir Controller.exe'
$startup.Checked = [IO.File]::Exists($startupPath)
$form.Controls.Add($startup)
$setStartup = (Get-Command Set-FeirStartup).ScriptBlock
$startupState = @{ Updating = $false }
$startup.add_CheckedChanged({
    if ($startupState.Updating) { return }
    try {
        & $setStartup $startupPath $launcherPath $startup.Checked
        $hint.Text = if ($startup.Checked) {
            'O Feir Controller vai iniciar na bandeja ao entrar no Windows.'
        } else {
            'Inicialização automática desativada.'
        }
    } catch {
        $startupState.Updating = $true
        $startup.Checked = [IO.File]::Exists($startupPath)
        $startupState.Updating = $false
        $hint.Text = "Não foi possível atualizar a inicialização. $($_.Exception.Message)"
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
$picker.add_SelectedIndexChanged({
    if (-not $session.UpdatingPicker -and $list.SelectedIndices.Count -eq 1 -and $picker.SelectedIndex -ge 0) {
        $session.LearnIndex = -1
        $index = $list.SelectedIndices[0]
        $session.Slots[$session.Selected].Draft[$index] = $picker.SelectedIndex - 1
        $list.Items[$index].SubItems[1].Text = [string]$picker.SelectedItem
        $hint.Text = 'Alteração pendente. Clique em Salvar mapeamento.'
    }
}.GetNewClosure())
$learn.add_Click({
    if (-not $session.Slots[$session.Selected].Connected) { $hint.Text = 'Conecte o controle Feir para detectar um botão.'; return }
    if ($list.SelectedIndices.Count -ne 1) { return }
    $session.LearnIndex = $list.SelectedIndices[0]
    $hint.Text = 'Pressione um botão físico do Feir…'
}.GetNewClosure())
$reset.add_Click({
    $session.LearnIndex = -1
    foreach ($index in 0..11) {
        $session.Slots[$session.Selected].Draft[$index] = $index
        $list.Items[$index].SubItems[1].Text = $inputNames[$index + 1]
    }
    if ($list.SelectedIndices.Count -eq 1) {
        $session.UpdatingPicker = $true
        $picker.SelectedIndex = $list.SelectedIndices[0] + 1
        $session.UpdatingPicker = $false
    }
    $hint.Text = 'Padrão restaurado. Clique em Salvar mapeamento.'
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
        $hint.Text = 'Mapeamento salvo e aplicado.'
    } catch {
        $hint.Text = "Não foi possível salvar. $($_.Exception.Message)"
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




foreach ($slotIndex in 0..1) {
    $slotButtons[$slotIndex].add_Click({
        $session.Selected = $slotIndex
        $session.LearnIndex = -1
        $slot = $session.Slots[$slotIndex]
        foreach ($index in 0..11) {
            $list.Items[$index].SubItems[1].Text = $inputNames[1 + $slot.Draft[$index]]
        }
        foreach ($i in 0..1) {
            $color = if ($i -eq $slotIndex) { '#3458B1' } else { '#242C3A' }
            $slotButtons[$i].BackColor = [Drawing.ColorTranslator]::FromHtml($color)
        }
        if ($list.SelectedIndices.Count -eq 1) {
            $session.UpdatingPicker = $true
            $picker.SelectedIndex = 1 + $slot.Draft[$list.SelectedIndices[0]]
            $session.UpdatingPicker = $false
        }
        $hint.Text = if (($slot.Draft -join ',') -eq ($slot.Map -join ',')) {
            'Os botões pressionados aparecem em tempo real.'
        } else { 'Alteração pendente. Clique em Salvar mapeamento.' }
    }.GetNewClosure())
}

$connectedColor = [Drawing.ColorTranslator]::FromHtml('#6EE7B7')
$disconnectedColor = [Drawing.ColorTranslator]::FromHtml('#94A3B8')
$pressedColor = [Drawing.ColorTranslator]::FromHtml('#24584F')
$rowColors = @(
    [Drawing.ColorTranslator]::FromHtml('#191F2B')
    [Drawing.ColorTranslator]::FromHtml('#1D2533')
)
function Update-FeirStatus {
    foreach ($i in 0..1) {
        $label = $slotStatus[$i]
        $connected = $session.Slots[$i].Connected
        $text = if ($connected) { '●  Conectado' } else { '○  Desconectado' }
        if ($label.Text -ne $text) {
            $label.Text = $text
            $label.ForeColor = if ($connected) { $connectedColor } else { $disconnectedColor }
        }
    }
    $slot = $session.Slots[$session.Selected]
    foreach ($i in 0..11) {
        $physical = $slot.Draft[$i]
        $pressed = $slot.Connected -and $physical -ge 0 -and $slot.Input[$physical]
        $row = $list.Items[$i]
        $text = if ($pressed) { 'Pressionado' } else { '—' }
        $color = if ($pressed) { $pressedColor } else { $rowColors[$i % 2] }
        if ($row.SubItems[2].Text -ne $text) { $row.SubItems[2].Text = $text }
        if ($row.BackColor -ne $color) { $row.BackColor = $color }
    }
}





