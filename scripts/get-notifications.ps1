<#
.SYNOPSIS
    Reads phone notifications from the Phone Link Notifications panel.
.PARAMETER MaxNotifications
    Maximum number of notifications to extract (default: 30).
#>
param(
    [int]$MaxNotifications = 30
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\uiautomation-core.ps1"

try {
    $win = Find-PhoneLinkWindow
    if (-not $win) {
        $win = Start-PhoneLink
        if (-not $win) {
            ConvertTo-McpJson @{ error = "Cannot find or launch Phone Link"; notifications = @() }
            return
        }
    }

    $connection = Get-PhoneLinkConnectionSnapshot -Window $win
    if (-not $connection.connected) {
        ConvertTo-McpJson @{
            error              = "Phone Link is disconnected"
            connected          = $false
            status             = $connection.status
            notification_count = 0
            notifications      = @()
        }
        return
    }

    # Navigate to Notifications. This is usually shown in the sidebar or as a panel.
    $tabNames = @("Notifications", "Notifiche", "Benachrichtigungen", "Notificaciones")
    $clicked = $false
    foreach ($tabName in $tabNames) {
        $tab = Find-ElementsByName -Root $win -NameContains $tabName -MaxDepth 6 |
               Select-Object -First 1
        if ($tab) {
            Invoke-ElementClick -Element $tab | Out-Null
            Start-Sleep -Seconds 2
            $clicked = $true
            break
        }
    }

    if (-not $clicked) {
        $notiTab = Find-ElementByAutomationId -Root $win -AutomationId "NotificationsNavButton"
        if (-not $notiTab) {
            $notiTab = Find-ElementByAutomationId -Root $win -AutomationId "NotificationsTab"
        }
        if ($notiTab) {
            Invoke-ElementClick -Element $notiTab | Out-Null
            Start-Sleep -Seconds 2
        }
    }

    Start-Sleep -Seconds 1

    $allElements = Get-AllDescendants -Element $win -MaxDepth 15
    $notifications = @()

    foreach ($el in $allElements) {
        try {
            $name = Normalize-UiText $el.Current.Name
            $ctrlType = $el.Current.ControlType.ProgrammaticName -replace '^ControlType\.', ''
            $autoId = Normalize-UiText $el.Current.AutomationId
            $className = Normalize-UiText $el.Current.ClassName

            if (-not $name -or $name.Length -lt 2) { continue }

            if ($ctrlType -in @("ListItem", "DataItem", "Custom", "Group")) {
                if ($name -match "^(Messages|Calls|Photos|Notifications|Apps)$") { continue }
                if ($name -match "^(Messaggi|Chiamate|Foto|Notifiche|App)$") { continue }

                $notifications += @{
                    text          = $name
                    control_type  = $ctrlType
                    automation_id = $autoId
                    class_name    = $className
                }
            }
        } catch { continue }
    }

    $notifications = $notifications | Select-Object -First $MaxNotifications

    ConvertTo-McpJson @{
        notification_count = $notifications.Count
        notifications      = $notifications
    }
} catch {
    ConvertTo-McpJson @{ error = $_.Exception.Message; notifications = @() }
}
