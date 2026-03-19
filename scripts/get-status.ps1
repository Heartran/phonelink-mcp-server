<#
.SYNOPSIS
    Gets Phone Link connection status and basic phone info from the UI.
#>
param()

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\uiautomation-core.ps1"

try {
    $win = Find-PhoneLinkWindow
    if (-not $win) {
        ConvertTo-McpJson @{
            connected  = $false
            status     = "Phone Link is not running"
            phone_name = ""
        }
        return
    }

    $snapshot = Get-PhoneLinkConnectionSnapshot -Window $win

    ConvertTo-McpJson @{
        connected   = $snapshot.connected
        status      = $snapshot.status
        phone_name  = $snapshot.phone_name
        app_running = $true
        ui_texts    = $snapshot.ui_texts
    }
} catch {
    ConvertTo-McpJson @{
        error = $_.Exception.Message
        connected = $false
    }
}
