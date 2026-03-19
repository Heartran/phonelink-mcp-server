<#
.SYNOPSIS
    Sends an SMS message through the Phone Link UI.
.PARAMETER Recipient
    Contact name or phone number.
.PARAMETER MessageText
    The text message to send.
#>
param(
    [Parameter(Mandatory)][string]$Recipient,
    [Parameter(Mandatory)][string]$MessageText
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\uiautomation-core.ps1"

try {
    $win = Find-PhoneLinkWindow
    if (-not $win) {
        $win = Start-PhoneLink
        if (-not $win) {
            ConvertTo-McpJson @{ error = "Cannot find or launch Phone Link"; sent = $false }
            return
        }
    }

    $connection = Get-PhoneLinkConnectionSnapshot -Window $win
    if (-not $connection.connected) {
        ConvertTo-McpJson @{
            error     = "Phone Link is disconnected"
            connected = $false
            status    = $connection.status
            sent      = $false
        }
        return
    }

    # Navigate to Messages tab
    $tabNames = @("Messages", "Messaggi", "Nachrichten", "Mensajes")
    foreach ($tabName in $tabNames) {
        $tab = Find-ElementsByName -Root $win -NameContains $tabName -MaxDepth 6 |
               Select-Object -First 1
        if ($tab) {
            Invoke-ElementClick -Element $tab | Out-Null
            Start-Sleep -Seconds 2
            break
        }
    }

    Start-Sleep -Seconds 1

    # Click "New Message" button
    $newMsgNames = @("New message", "Nuovo messaggio", "Neue Nachricht", "Nuevo mensaje")
    $newMsgClicked = $false
    foreach ($btnName in $newMsgNames) {
        $btn = Find-ElementsByName -Root $win -NameContains $btnName -MaxDepth 8 |
               Select-Object -First 1
        if ($btn) {
            Invoke-ElementClick -Element $btn | Out-Null
            Start-Sleep -Seconds 2
            $newMsgClicked = $true
            break
        }
    }

    if (-not $newMsgClicked) {
        # Try AutomationId
        $newBtn = Find-ElementByAutomationId -Root $win -AutomationId "NewMessageButton"
        if ($newBtn) {
            Invoke-ElementClick -Element $newBtn | Out-Null
            Start-Sleep -Seconds 2
            $newMsgClicked = $true
        }
    }

    if (-not $newMsgClicked) {
        ConvertTo-McpJson @{ error = "Could not find 'New message' button"; sent = $false }
        return
    }

    # Find the recipient/To field and type the recipient
    $toField = $null
    $toNames = @("To", "A", "An", "Para")
    foreach ($fn in $toNames) {
        $candidates = Find-ElementsByName -Root $win -NameContains $fn -MaxDepth 10
        $toField = $candidates | Where-Object {
            try {
                $ct = $_.Current.ControlType.ProgrammaticName -replace '^ControlType\.', ''
                $ct -in @("Edit", "ComboBox", "Custom")
            } catch { $false }
        } | Select-Object -First 1
        if ($toField) { break }
    }

    if (-not $toField) {
        # Fallback: find any Edit element near the top
        $edits = Find-ElementsByControlType -Root $win -TypeName "Edit" -MaxDepth 10
        if ($edits -and $edits.Count -gt 0) {
            $toField = $edits[0]
        }
    }

    if ($toField) {
        Set-ElementValue -Element $toField -Text $Recipient | Out-Null
        Start-Sleep -Seconds 2

        # Press Enter to confirm recipient selection
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        Start-Sleep -Seconds 1
    } else {
        ConvertTo-McpJson @{ error = "Could not find recipient field"; sent = $false }
        return
    }

    # Find the message input field
    $msgField = $null
    $msgNames = @("Message", "Messaggio", "Nachricht", "Mensaje", "Type a message", "Scrivi un messaggio")
    foreach ($fn in $msgNames) {
        $candidates = Find-ElementsByName -Root $win -NameContains $fn -MaxDepth 12
        $msgField = $candidates | Where-Object {
            try {
                $ct = $_.Current.ControlType.ProgrammaticName -replace '^ControlType\.', ''
                $ct -in @("Edit", "Document", "Custom")
            } catch { $false }
        } | Select-Object -First 1
        if ($msgField) { break }
    }

    if (-not $msgField) {
        # Fallback: get the last Edit element (message box is usually at the bottom)
        $edits = Find-ElementsByControlType -Root $win -TypeName "Edit" -MaxDepth 12
        if ($edits -and $edits.Count -gt 1) {
            $msgField = $edits[-1]
        }
    }

    if ($msgField) {
        Set-ElementValue -Element $msgField -Text $MessageText | Out-Null
        Start-Sleep -Seconds 1
    } else {
        ConvertTo-McpJson @{ error = "Could not find message input field"; sent = $false }
        return
    }

    # Click Send button
    $sendNames = @("Send", "Invia", "Senden", "Enviar")
    $sent = $false
    foreach ($sn in $sendNames) {
        $sendBtn = Find-ElementsByName -Root $win -NameContains $sn -MaxDepth 10 |
                   Where-Object {
                       try {
                           $ct = $_.Current.ControlType.ProgrammaticName -replace '^ControlType\.', ''
                           $ct -in @("Button", "Custom")
                       } catch { $false }
                   } | Select-Object -First 1
        if ($sendBtn) {
            Invoke-ElementClick -Element $sendBtn | Out-Null
            $sent = $true
            break
        }
    }

    if (-not $sent) {
        # Fallback: press Enter
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        $sent = $true
    }

    Start-Sleep -Seconds 2

    ConvertTo-McpJson @{
        sent      = $sent
        recipient = $Recipient
        message   = $MessageText
    }
} catch {
    ConvertTo-McpJson @{ error = $_.Exception.Message; sent = $false }
}
