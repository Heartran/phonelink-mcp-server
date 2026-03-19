<#
.SYNOPSIS
    Dumps the Phone Link UI automation tree for debugging.
    Returns a JSON structure of all visible UI elements.
.PARAMETER MaxDepth
    Maximum tree depth to traverse (default: 10).
.PARAMETER FilterControlType
    Optional: only return elements of this control type.
#>
param(
    [int]$MaxDepth = 10,
    [string]$FilterControlType = ""
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\uiautomation-core.ps1"

try {
    $win = Find-PhoneLinkWindow
    if (-not $win) {
        ConvertTo-McpJson @{ error = "Phone Link window not found"; elements = @() }
        return
    }

    $allElements = Get-AllDescendants -Element $win -MaxDepth $MaxDepth
    $output = @()

    foreach ($el in $allElements) {
        try {
            $info = Get-ElementInfo -Element $el
            if ($info.Error) { continue }

            # Skip elements with no name and no automation id
            if (-not $info.Name -and -not $info.AutomationId) { continue }

            # Apply filter if specified
            if ($FilterControlType -and $info.ControlType -ne $FilterControlType) { continue }

            $output += $info
        } catch { continue }
    }

    # Limit output to prevent massive payloads
    $output = $output | Select-Object -First 200

    ConvertTo-McpJson @{
        element_count = $output.Count
        window_name   = $win.Current.Name
        elements      = $output
    }
} catch {
    ConvertTo-McpJson @{ error = $_.Exception.Message; elements = @() }
}
