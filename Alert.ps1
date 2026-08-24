Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Play-StretchChime {
    $wav = Join-Path $env:SystemRoot 'Media\Alarm01.wav'
    if (-not (Test-Path $wav)) { $wav = Join-Path $env:SystemRoot 'Media\notify.wav' }
    if (Test-Path $wav) {
        try {
            (New-Object System.Media.SoundPlayer $wav).Play()
            return
        } catch { }
    }
    [System.Media.SystemSounds]::Exclamation.Play()
}

function Show-StretchAlert {
    param(
        [int]$StretchMinutes = 10,
        [int]$SnoozeMinutes = 5,
        [bool]$Sound = $false
    )

    $state = @{
        Remaining = $StretchMinutes * 60
        Grace     = 0
        Result    = 'dismissed'
    }

    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Time to stretch'
    $form.ClientSize = New-Object System.Drawing.Size(504, 285)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(24, 28, 36)

    $heading = New-Object System.Windows.Forms.Label
    $heading.Text = 'Stand up and stretch'
    $heading.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 20)
    $heading.ForeColor = [System.Drawing.Color]::FromArgb(240, 244, 250)
    $heading.TextAlign = 'MiddleCenter'
    $heading.Dock = 'Top'
    $heading.Height = 60
    $form.Controls.Add($heading)

    $clock = New-Object System.Windows.Forms.Label
    $clock.Font = New-Object System.Drawing.Font('Segoe UI', 56, [System.Drawing.FontStyle]::Bold)
    $clock.ForeColor = [System.Drawing.Color]::FromArgb(126, 200, 227)
    $clock.TextAlign = 'MiddleCenter'
    $clock.Location = New-Object System.Drawing.Point(0, 65)
    $clock.Size = New-Object System.Drawing.Size(504, 110)
    $form.Controls.Add($clock)

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = 'Roll your shoulders, look 20 feet away, walk around.'
    $hint.Font = New-Object System.Drawing.Font('Segoe UI', 10)
    $hint.ForeColor = [System.Drawing.Color]::FromArgb(160, 170, 186)
    $hint.TextAlign = 'MiddleCenter'
    $hint.Location = New-Object System.Drawing.Point(0, 180)
    $hint.Size = New-Object System.Drawing.Size(504, 24)
    $form.Controls.Add($hint)

    $snoozeButton = New-Object System.Windows.Forms.Button
    $snoozeButton.Text = "Snooze $SnoozeMinutes min"
    $snoozeButton.Size = New-Object System.Drawing.Size(150, 40)
    $snoozeButton.Location = New-Object System.Drawing.Point(90, 220)
    $snoozeButton.FlatStyle = 'Flat'
    $snoozeButton.BackColor = [System.Drawing.Color]::FromArgb(44, 50, 62)
    $snoozeButton.ForeColor = [System.Drawing.Color]::FromArgb(230, 236, 245)
    $form.Controls.Add($snoozeButton)

    $doneButton = New-Object System.Windows.Forms.Button
    $doneButton.Text = 'Done'
    $doneButton.Size = New-Object System.Drawing.Size(150, 40)
    $doneButton.Location = New-Object System.Drawing.Point(264, 220)
    $doneButton.FlatStyle = 'Flat'
    $doneButton.BackColor = [System.Drawing.Color]::FromArgb(58, 116, 138)
    $doneButton.ForeColor = [System.Drawing.Color]::White
    $form.Controls.Add($doneButton)

    $render = { '{0:00}:{1:00}' -f [math]::Floor($state.Remaining / 60), ($state.Remaining % 60) }
    $clock.Text = & $render

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        if ($state.Remaining -gt 0) {
            $state.Remaining--
            $clock.Text = & $render
            if ($state.Remaining -eq 0) {
                $heading.Text = 'Stretch done - back to it'
                $clock.ForeColor = [System.Drawing.Color]::FromArgb(140, 205, 150)
                $snoozeButton.Enabled = $false
                $state.Result = 'completed'
                $state.Grace = 15
                if ($Sound) { Play-StretchChime }
            }
        } elseif ($state.Grace -gt 0) {
            $state.Grace--
            if ($state.Grace -eq 0) { $form.Close() }
        }
    })

    $snoozeButton.Add_Click({
        $state.Result = 'snoozed'
        $form.Close()
    })

    $doneButton.Add_Click({
        $state.Result = 'dismissed'
        $form.Close()
    })

    $form.Add_Shown({
        $form.Activate()
        if ($Sound) { Play-StretchChime }
    })

    $timer.Start()
    [void]$form.ShowDialog()
    $timer.Stop()
    $timer.Dispose()
    $form.Dispose()

    $state.Result
}
