<#
.SYNOPSIS
    Reads SMS/messages from the Phone Link Messages tab.
.PARAMETER NavigateToTab
    Whether to click on the Messages tab first (default: true).
.PARAMETER ConversationName
    Optional: open a specific conversation by contact name.
.PARAMETER MaxMessages
    Maximum number of messages to extract (default: 20).
#>
param(
    [bool]$NavigateToTab = $true,
    [string]$ConversationName = "",
    [int]$MaxMessages = 20
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\uiautomation-core.ps1"

try {
    $win = Find-PhoneLinkWindow
    if (-not $win) {
        $win = Start-PhoneLink
        if (-not $win) {
            ConvertTo-McpJson @{ error = "Cannot find or launch Phone Link"; messages = @() }
            return
        }
    }

    # Navigate to Messages tab
    if ($NavigateToTab) {
        $tabNames = @("Messages", "Messaggi", "Nachrichten", "Mensajes")
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
            # Try clicking by AutomationId patterns
            $msgTab = Find-ElementByAutomationId -Root $win -AutomationId "MessageNavButton"
            if (-not $msgTab) {
                $msgTab = Find-ElementByAutomationId -Root $win -AutomationId "MessagesTab"
            }
            if ($msgTab) {
                Invoke-ElementClick -Element $msgTab | Out-Null
                Start-Sleep -Seconds 2
            }
        }
    }

    Start-Sleep -Seconds 1

    # If a specific conversation is requested, find and click it
    if ($ConversationName) {
        $convElements = Find-ElementsByName -Root $win -NameContains $ConversationName -MaxDepth 10
        $conv = $convElements | Where-Object {
            try {
                $ct = $_.Current.ControlType.ProgrammaticName -replace '^ControlType\.', ''
                $ct -in @("ListItem", "Button", "Custom", "DataItem")
            } catch { $false }
        } | Select-Object -First 1

        if ($conv) {
            Invoke-ElementClick -Element $conv | Out-Null
            Start-Sleep -Seconds 2
        }
    }

    # Scrape visible messages
    $allElements = Get-AllDescendants -Element $win -MaxDepth 20
    $messages = @()
    $conversationList = @()

    foreach ($el in $allElements) {
        try {
            $name = $el.Current.Name
            $ctrlType = $el.Current.ControlType.ProgrammaticName -replace '^ControlType\.', ''
            $autoId = $el.Current.AutomationId
            $className = $el.Current.ClassName

            if (-not $name -or $name.Length -lt 2) { continue }

            # Conversation list items (when no conversation is open)
            if ($ctrlType -in @("ListItem", "DataItem") -and -not $ConversationName) {
                # These typically contain contact name + last message preview + timestamp
                $conversationList += @{
                    contact      = $name
                    control_type = $ctrlType
                    automation_id = $autoId
                }
            }

            # Individual messages inside a conversation
            if ($ConversationName -and $ctrlType -in @("ListItem", "DataItem", "Text", "Custom")) {
                # Messages typically have a pattern: sender + text + timestamp
                if ($autoId -match "(?i)message" -or $className -match "(?i)message" -or
                    $ctrlType -eq "ListItem") {
                    $messages += @{
                        text          = $name
                        control_type  = $ctrlType
                        automation_id = $autoId
                        class_name    = $className
                    }
                }
            }
        } catch { continue }
    }

    # Trim to max
    if ($ConversationName) {
        $messages = $messages | Select-Object -First $MaxMessages
        ConvertTo-McpJson @{
            conversation = $ConversationName
            message_count = $messages.Count
            messages = $messages
        }
    } else {
        $conversationList = $conversationList | Select-Object -First $MaxMessages
        ConvertTo-McpJson @{
            conversation_count = $conversationList.Count
            conversations = $conversationList
        }
    }
} catch {
    ConvertTo-McpJson @{ error = $_.Exception.Message; messages = @() }
}
