<#
.SYNOPSIS
    Initiates a phone call through Phone Link's Calls tab dialer.
.PARAMETER PhoneNumber
    The phone number to call.
#>
param(
    [Parameter(Mandatory)][string]$PhoneNumber
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\uiautomation-core.ps1"

try {
    $win = Find-PhoneLinkWindow
    if (-not $win) {
        $win = Start-PhoneLink
        if (-not $win) {
            ConvertTo-McpJson @{ error = "Cannot find or launch Phone Link"; initiated = $false }
            return
        }
    }

    $connection = Get-PhoneLinkConnectionSnapshot -Window $win
    if (-not $connection.connected) {
        ConvertTo-McpJson @{
            error     = "Phone Link is disconnected"
            connected = $false
            status    = $connection.status
            initiated = $false
        }
        return
    }

    # Navigate to Calls tab
    $tabNames = @("Calls", "Chiamate", "Anrufe", "Llamadas")
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

    # Look for the dialer/dial pad — usually opened via a button
    $dialerNames = @("Dial pad", "Tastierino", "Wähltastatur", "Teclado", "Dial")
    foreach ($dn in $dialerNames) {
        $dialBtn = Find-ElementsByName -Root $win -NameContains $dn -MaxDepth 8 |
                   Select-Object -First 1
        if ($dialBtn) {
            Invoke-ElementClick -Element $dialBtn | Out-Null
            Start-Sleep -Seconds 1
            break
        }
    }

    # Find the phone number input field
    $phoneField = $null
    $fieldNames = @("Phone number", "Numero di telefono", "Telefonnummer", "Número de teléfono",
                    "Enter a name or number", "Inserisci un nome o un numero")
    foreach ($fn in $fieldNames) {
        $candidates = Find-ElementsByName -Root $win -NameContains $fn -MaxDepth 10
        $phoneField = $candidates | Where-Object {
            try {
                $ct = $_.Current.ControlType.ProgrammaticName -replace '^ControlType\.', ''
                $ct -in @("Edit", "ComboBox", "Custom")
            } catch { $false }
        } | Select-Object -First 1
        if ($phoneField) { break }
    }

    if (-not $phoneField) {
        $edits = Find-ElementsByControlType -Root $win -TypeName "Edit" -MaxDepth 10
        if ($edits -and $edits.Count -gt 0) {
            $phoneField = $edits[0]
        }
    }

    if ($phoneField) {
        Set-ElementValue -Element $phoneField -Text $PhoneNumber | Out-Null
        Start-Sleep -Seconds 1
    } else {
        ConvertTo-McpJson @{ error = "Could not find phone number field"; initiated = $false }
        return
    }

    # Click the call/dial button
    $callNames = @("Call", "Chiama", "Anrufen", "Llamar")
    $initiated = $false
    foreach ($cn in $callNames) {
        $callBtn = Find-ElementsByName -Root $win -NameContains $cn -MaxDepth 10 |
                   Where-Object {
                       try {
                           $ct = $_.Current.ControlType.ProgrammaticName -replace '^ControlType\.', ''
                           $ct -in @("Button", "Custom")
                       } catch { $false }
                   } | Select-Object -First 1
        if ($callBtn) {
            Invoke-ElementClick -Element $callBtn | Out-Null
            $initiated = $true
            break
        }
    }

    if (-not $initiated) {
        [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
        $initiated = $true
    }

    ConvertTo-McpJson @{
        initiated    = $initiated
        phone_number = $PhoneNumber
    }
} catch {
    ConvertTo-McpJson @{ error = $_.Exception.Message; initiated = $false }
}
