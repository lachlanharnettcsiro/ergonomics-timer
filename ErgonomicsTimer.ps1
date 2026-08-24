[CmdletBinding()]
param(
    [switch]$TestAlert
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $root 'Alert.ps1')

$configPath = Join-Path $root 'config.json'
$logPath = Join-Path $env:TEMP 'ergonomics-timer.log'

function Write-Log([string]$message) {
    try {
        "$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')) $message" | Add-Content $logPath -Encoding UTF8
    } catch { }
}

$defaults = [ordered]@{
    times          = @('09:50', '10:50', '11:50', '12:50', '13:50', '14:50', '15:50', '16:50')
    stretchMinutes = 10
    snoozeMinutes  = 5
    sound          = $false
    weekdaysOnly   = $true
}

function Read-Config {
    $config = [ordered]@{}
    foreach ($key in $defaults.Keys) { $config[$key] = $defaults[$key] }
    if (Test-Path $configPath) {
        try {
            $loaded = Get-Content $configPath -Raw | ConvertFrom-Json
            foreach ($key in @($config.Keys)) {
                if ($null -ne $loaded.$key) { $config[$key] = $loaded.$key }
            }
        } catch {
            [System.Windows.Forms.MessageBox]::Show(
                "config.json could not be read, using defaults.`n`n$($_.Exception.Message)",
                'Ergonomics Timer', 'OK', 'Warning') | Out-Null
        }
    }
    $config
}

function Write-Config($config) {
    try {
        [pscustomobject]$config | ConvertTo-Json -Depth 4 | Set-Content $configPath -Encoding UTF8
    } catch { }
}

function New-TrayIcon {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $g.Clear([System.Drawing.Color]::Transparent)

    $disc = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(58, 116, 138))
    $g.FillEllipse($disc, 0, 0, 31, 31)

    $ink = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 2.6
    $ink.StartCap = 'Round'
    $ink.EndCap = 'Round'
    $white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)

    $g.FillEllipse($white, 13, 5, 7, 7)
    $g.DrawLine($ink, 16, 13, 16, 21)
    $g.DrawLine($ink, 8, 9, 16, 15)
    $g.DrawLine($ink, 24, 9, 16, 15)
    $g.DrawLine($ink, 16, 21, 11, 27)
    $g.DrawLine($ink, 16, 21, 21, 27)

    $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $disc.Dispose(); $ink.Dispose(); $white.Dispose(); $g.Dispose(); $bmp.Dispose()
    $icon
}

$config = Read-Config

if ($TestAlert) {
    do {
        $result = Show-StretchAlert -StretchMinutes $config.stretchMinutes `
            -SnoozeMinutes $config.snoozeMinutes -Sound ([bool]$config.sound)
        if ($result -eq 'snoozed') { Start-Sleep -Seconds ($config.snoozeMinutes * 60) }
    } while ($result -eq 'snoozed')
    return
}

$mutex = New-Object System.Threading.Mutex($false, 'Global\ErgonomicsTimer.SingleInstance')
if (-not $mutex.WaitOne(0)) {
    [System.Windows.Forms.MessageBox]::Show('Ergonomics Timer is already running.',
        'Ergonomics Timer', 'OK', 'Information') | Out-Null
    return
}

$app = @{
    Fired      = @{}
    Pending    = $null
    Showing    = $false
    PausedDate = $null
}

function Get-SlotTimes {
    foreach ($t in $config.times) {
        $parsed = [datetime]::MinValue
        if ([datetime]::TryParseExact($t, 'HH:mm', [cultureinfo]::InvariantCulture, 'None', [ref]$parsed)) {
            (Get-Date).Date.AddHours($parsed.Hour).AddMinutes($parsed.Minute)
        }
    }
}

function Test-ActiveToday {
    if ($config.weekdaysOnly -and (Get-Date).DayOfWeek -in @('Saturday', 'Sunday')) { return $false }
    if ($app.PausedDate -eq (Get-Date).Date) { return $false }
    $true
}

function Get-NextSlot {
    if (-not (Test-ActiveToday)) { return $null }
    $now = Get-Date
    Get-SlotTimes | Where-Object { $_ -gt $now } | Sort-Object | Select-Object -First 1
}

$icon = New-TrayIcon

$menu = New-Object System.Windows.Forms.ContextMenuStrip

$nextItem = $menu.Items.Add('Next: -')
$nextItem.Enabled = $false
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$nowItem = $menu.Items.Add('Stretch now')
$soundItem = $menu.Items.Add('Sound')
$soundItem.CheckOnClick = $true
$soundItem.Checked = [bool]$config.sound
$pauseItem = $menu.Items.Add('Pause for today')
$pauseItem.CheckOnClick = $true
[void]$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
$folderItem = $menu.Items.Add('Open folder')
$exitItem = $menu.Items.Add('Exit')

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = $icon
$notify.Text = 'Ergonomics Timer'
$notify.ContextMenuStrip = $menu
$notify.Visible = $true

function Invoke-Alert {
    if ($app.Showing) { return }
    $app.Showing = $true
    try {
        $result = Show-StretchAlert -StretchMinutes $config.stretchMinutes `
            -SnoozeMinutes $config.snoozeMinutes -Sound ([bool]$config.sound)
        Write-Log "alert closed: $result"
        if ($result -eq 'snoozed') {
            $app.Pending = (Get-Date).AddMinutes($config.snoozeMinutes)
        } else {
            $app.Pending = $null
        }
    } catch {
        Write-Log "alert error: $($_.Exception.Message)"
    } finally {
        $app.Showing = $false
    }
}

function Update-Tooltip {
    $next = Get-NextSlot
    if ($app.Pending) {
        $label = "Snoozed until $($app.Pending.ToString('h:mm tt'))"
    } elseif ($next) {
        $label = "Next: $($next.ToString('h:mm tt'))"
    } elseif (-not (Test-ActiveToday)) {
        $label = 'Paused today'
    } else {
        $label = 'Next: tomorrow'
    }
    $nextItem.Text = $label
    $notify.Text = "Ergonomics Timer - $label"
}

$scheduler = New-Object System.Windows.Forms.Timer
$scheduler.Interval = 10000
$scheduler.Add_Tick({
    try {
        if ($app.Showing) { return }
        $now = Get-Date

        if ($app.Pending) {
            if ($now -ge $app.Pending) {
                $app.Pending = $null
                Write-Log 'snooze elapsed, re-alerting'
                Invoke-Alert
                Update-Tooltip
            }
            return
        }

        if (Test-ActiveToday) {
            foreach ($slot in Get-SlotTimes) {
                $key = $slot.ToString('yyyy-MM-dd HH:mm')
                if ($app.Fired.ContainsKey($key)) { continue }
                if ($now -ge $slot -and $now -lt $slot.AddMinutes(2)) {
                    $app.Fired[$key] = $true
                    Write-Log "alert for slot $key"
                    Invoke-Alert
                    break
                }
            }
        }

        Update-Tooltip
    } catch {
        Write-Log "tick error: $($_.Exception.Message)"
    }
})

$nowItem.Add_Click({
    Invoke-Alert
    Update-Tooltip
})

$soundItem.Add_Click({
    $config.sound = $soundItem.Checked
    Write-Config $config
})

$pauseItem.Add_Click({
    if ($pauseItem.Checked) {
        $app.PausedDate = (Get-Date).Date
        $app.Pending = $null
    } else {
        $app.PausedDate = $null
    }
    Update-Tooltip
})

$folderItem.Add_Click({ Start-Process explorer.exe $root })

$exitItem.Add_Click({
    $scheduler.Stop()
    $notify.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})

$notify.Add_MouseDoubleClick({
    Invoke-Alert
    Update-Tooltip
})

Update-Tooltip
Write-Log "started; times $($config.times -join ', '); sound $($config.sound)"
$scheduler.Start()
[System.Windows.Forms.Application]::Run()

$scheduler.Dispose()
$notify.Dispose()
$icon.Dispose()
$menu.Dispose()
$mutex.ReleaseMutex()
$mutex.Dispose()
