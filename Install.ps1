[CmdletBinding()]
param(
    [string]$TaskName = 'ErgonomicsTimer',
    [switch]$NoStart
)

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$launcher = Join-Path $root 'run-hidden.vbs'
if (-not (Test-Path $launcher)) { throw "Launcher not found: $launcher" }

Get-ChildItem -Path $root -File | Unblock-File -ErrorAction SilentlyContinue

$trigger = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
$trigger.Delay = 'PT30S'

$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\wscript.exe" `
    -Argument "`"$launcher`"" -WorkingDirectory $root

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit (New-TimeSpan -Seconds 0)

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName `
    -Description 'Ergonomics Timer: tray app that prompts a 10 minute stretch every hour.' `
    -Trigger $trigger -Action $action -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "Installed '$TaskName' - starts at logon, 30s delay."
Write-Host "Alert times live in config.json: $(( (Get-Content (Join-Path $root 'config.json') -Raw | ConvertFrom-Json).times ) -join ', ')"

if (-not $NoStart) {
    Start-Process "$env:SystemRoot\System32\wscript.exe" -ArgumentList "`"$launcher`""
    Write-Host 'Started now - look for the tray icon.'
}
