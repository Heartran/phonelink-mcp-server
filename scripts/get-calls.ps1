<#
.SYNOPSIS
    Reads call history from the Phone Link Calls tab.
.PARAMETER MaxCalls
    Maximum number of call entries to extract (default: 20).
#>
param(
    [int]$MaxCalls = 20
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\uiautomation-core.ps1"

try {
    $win = Find-PhoneLinkWindow
    if (-not $win) {
        $win = Start-PhoneLink
        if (-not $win) {
            ConvertTo-McpJson @{ error = "Cannot find or launch Phone Link"; calls = @() }
            return
        }
    }

    # Navigate to Calls tab
    $tabNames = @("Calls", "Chiamate", "Anrufe", "Llamadas")
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
        $callTab = Find-ElementByAutomationId -Root $win -AutomationId "CallsNavButton"
        if (-not $callTab) {
            $callTab = Find-ElementByAutomationId -Root $win -AutomationId "CallsTab"
        }
        if ($callTab) {
            Invoke-ElementClick -Element $callTab | Out-Null
            Start-Sleep -Seconds 2
        }
    }

    Start-Sleep -Seconds 1

    # Scrape call list
    $allElements = Get-AllDescendants -Element $win -MaxDepth 15
    $calls = @()

    foreach ($el in $allElements) {
        try {
            $name = $el.Current.Name
            $ctrlType = $el.Current.ControlType.ProgrammaticName -replace '^ControlType\.', ''
            $autoId = $el.Current.AutomationId

            if (-not $name -or $name.Length -lt 2) { continue }

            # Call entries are typically ListItems
            if ($ctrlType -in @("ListItem", "DataItem")) {
                # Parse call info from the element name
                # Typical format: "Contact Name, Incoming/Outgoing/Missed, Time"
                $callType = "unknown"
                if ($name -match "(?i)(incoming|in arrivo|ricevuta|eingehend)") { $callType = "incoming" }
                elseif ($name -match "(?i)(outgoing|in uscita|effettuata|ausgehend)") { $callType = "outgoing" }
                elseif ($name -match "(?i)(missed|persa|perdida|verpasst)") { $callType = "missed" }

                $calls += @{
                    display_text  = $name
                    call_type     = $callType
                    automation_id = $autoId
                }
            }
        } catch { continue }
    }

    $calls = $calls | Select-Object -First $MaxCalls

    ConvertTo-McpJson @{
        call_count = $calls.Count
        calls      = $calls
    }
} catch {
    ConvertTo-McpJson @{ error = $_.Exception.Message; calls = @() }
}
