<#
.SYNOPSIS
    Core UIAutomation helpers for Phone Link MCP Server.
    Provides functions to find, read, and interact with Phone Link UI elements.
#>

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms

try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [Console]::InputEncoding = $utf8NoBom
    [Console]::OutputEncoding = $utf8NoBom
    $OutputEncoding = $utf8NoBom
} catch {}

$Automation = [System.Windows.Automation.AutomationElement]
$TreeWalker = [System.Windows.Automation.TreeWalker]::RawViewWalker
$Condition  = [System.Windows.Automation.Condition]
$PropertyCondition = [System.Windows.Automation.PropertyCondition]
$AndCondition = [System.Windows.Automation.AndCondition]
$OrCondition  = [System.Windows.Automation.OrCondition]
$TrueCondition = [System.Windows.Automation.Condition]::TrueCondition

# Pattern types
$InvokePattern    = [System.Windows.Automation.InvokePattern]::Pattern
$ValuePattern     = [System.Windows.Automation.ValuePattern]::Pattern
$SelectionItem    = [System.Windows.Automation.SelectionItemPattern]::Pattern
$ScrollPattern    = [System.Windows.Automation.ScrollPattern]::Pattern
$TextPattern      = [System.Windows.Automation.TextPattern]::Pattern
$ExpandCollapse   = [System.Windows.Automation.ExpandCollapsePattern]::Pattern

# Control types
$ControlType = [System.Windows.Automation.ControlType]

function Normalize-UiText {
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) {
        return $null
    }

    try {
        $Text = $Text.Normalize([System.Text.NormalizationForm]::FormKC)
    } catch {}

    $normalized = [regex]::Replace($Text, '\p{Cf}', '')
    $normalized = [regex]::Replace($normalized, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', ' ')
    $normalized = [regex]::Replace($normalized, '\s{2,}', ' ')

    return $normalized.Trim()
}

function Find-PhoneLinkWindow {
    <#
    .SYNOPSIS
        Finds the Phone Link main window. Tries both "Phone Link" and "Collegamento al telefono" (Italian).
    #>
    $root = $Automation::RootElement

    $names = @("Phone Link", "Collegamento al telefono", "Il tuo telefono", "Your Phone")
    foreach ($name in $names) {
        $cond = New-Object System.Windows.Automation.PropertyCondition(
            $Automation::NameProperty, $name
        )
        $win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
        if ($win) { return $win }
    }

    # Fallback: search by process name
    $proc = Get-Process -Name "PhoneExperienceHost" -ErrorAction SilentlyContinue |
            Select-Object -First 1
    if ($proc -and $proc.MainWindowHandle -ne 0) {
        return $Automation::FromHandle($proc.MainWindowHandle)
    }

    return $null
}

function Get-AllDescendants {
    <#
    .SYNOPSIS
        Recursively collects all descendants of an AutomationElement, up to a max depth.
    #>
    param(
        [System.Windows.Automation.AutomationElement]$Element,
        [int]$MaxDepth = 15,
        [int]$CurrentDepth = 0
    )

    if ($CurrentDepth -ge $MaxDepth) { return @() }

    $results = @()
    $child = $TreeWalker.GetFirstChild($Element)
    while ($child) {
        $results += $child
        $results += Get-AllDescendants -Element $child -MaxDepth $MaxDepth -CurrentDepth ($CurrentDepth + 1)
        $child = $TreeWalker.GetNextSibling($child)
    }
    return $results
}

function Get-ElementInfo {
    <#
    .SYNOPSIS
        Extracts key properties from an AutomationElement into a hashtable.
    #>
    param([System.Windows.Automation.AutomationElement]$Element)

    try {
        $name = Normalize-UiText $Element.Current.Name
        $controlType = $Element.Current.ControlType.ProgrammaticName
        $automationId = Normalize-UiText $Element.Current.AutomationId
        $className = Normalize-UiText $Element.Current.ClassName
        $isEnabled = $Element.Current.IsEnabled
        $rect = $Element.Current.BoundingRectangle

        # Try to get Value pattern text
        $value = ""
        try {
            $vp = $Element.GetCurrentPattern($ValuePattern)
            if ($vp) { $value = Normalize-UiText $vp.Current.Value }
        } catch {}

        return @{
            Name         = $name
            ControlType  = $controlType -replace '^ControlType\.', ''
            AutomationId = $automationId
            ClassName    = $className
            IsEnabled    = $isEnabled
            Value        = $value
            BoundingRect = @{
                X      = [math]::Round($rect.X)
                Y      = [math]::Round($rect.Y)
                Width  = [math]::Round($rect.Width)
                Height = [math]::Round($rect.Height)
            }
        }
    } catch {
        return @{ Error = $_.Exception.Message }
    }
}

function Find-ElementsByName {
    <#
    .SYNOPSIS
        Finds all descendant elements whose Name contains the given substring.
    #>
    param(
        [System.Windows.Automation.AutomationElement]$Root,
        [string]$NameContains,
        [int]$MaxDepth = 15
    )

    $all = Get-AllDescendants -Element $Root -MaxDepth $MaxDepth
    return $all | Where-Object {
        try { $_.Current.Name -like "*$NameContains*" } catch { $false }
    }
}

function Find-ElementsByControlType {
    <#
    .SYNOPSIS
        Finds all descendant elements of a specific control type.
    #>
    param(
        [System.Windows.Automation.AutomationElement]$Root,
        [string]$TypeName,
        [int]$MaxDepth = 15
    )

    $all = Get-AllDescendants -Element $Root -MaxDepth $MaxDepth
    return $all | Where-Object {
        try {
            ($_.Current.ControlType.ProgrammaticName -replace '^ControlType\.', '') -eq $TypeName
        } catch { $false }
    }
}

function Find-ElementByAutomationId {
    <#
    .SYNOPSIS
        Finds the first element with a matching AutomationId.
    #>
    param(
        [System.Windows.Automation.AutomationElement]$Root,
        [string]$AutomationId
    )

    $cond = New-Object System.Windows.Automation.PropertyCondition(
        $Automation::AutomationIdProperty, $AutomationId
    )
    return $Root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $cond)
}

function Invoke-ElementClick {
    <#
    .SYNOPSIS
        Clicks an element via InvokePattern or falls back to SetFocus + mouse click.
    #>
    param([System.Windows.Automation.AutomationElement]$Element)

    try {
        $pattern = $Element.GetCurrentPattern($InvokePattern)
        $pattern.Invoke()
        return $true
    } catch {
        try {
            $Element.SetFocus()
            $rect = $Element.Current.BoundingRectangle
            $x = [int]($rect.X + $rect.Width / 2)
            $y = [int]($rect.Y + $rect.Height / 2)
            [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y)
            Start-Sleep -Milliseconds 100

            Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class MouseHelper {
    [DllImport("user32.dll")] public static extern void mouse_event(int dwFlags, int dx, int dy, int dwData, int dwExtraInfo);
    public const int MOUSEEVENTF_LEFTDOWN = 0x02;
    public const int MOUSEEVENTF_LEFTUP   = 0x04;
    public static void Click() {
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
        mouse_event(MOUSEEVENTF_LEFTUP,   0, 0, 0, 0);
    }
}
"@ -ErrorAction SilentlyContinue

            [MouseHelper]::Click()
            return $true
        } catch {
            return $false
        }
    }
}

function Set-ElementValue {
    <#
    .SYNOPSIS
        Sets text in an element via ValuePattern or falls back to SendKeys.
    #>
    param(
        [System.Windows.Automation.AutomationElement]$Element,
        [string]$Text
    )

    try {
        $vp = $Element.GetCurrentPattern($ValuePattern)
        $vp.SetValue($Text)
        return $true
    } catch {
        try {
            $Element.SetFocus()
            Start-Sleep -Milliseconds 200
            [System.Windows.Forms.SendKeys]::SendWait($Text)
            return $true
        } catch {
            return $false
        }
    }
}

function Wait-ForElement {
    <#
    .SYNOPSIS
        Polls for an element matching a condition, with timeout.
    #>
    param(
        [System.Windows.Automation.AutomationElement]$Root,
        [string]$AutomationId = "",
        [string]$NameContains = "",
        [int]$TimeoutSeconds = 10,
        [int]$PollIntervalMs = 500
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        if ($AutomationId) {
            $el = Find-ElementByAutomationId -Root $Root -AutomationId $AutomationId
            if ($el) { return $el }
        }
        if ($NameContains) {
            $els = Find-ElementsByName -Root $Root -NameContains $NameContains -MaxDepth 10
            if ($els -and $els.Count -gt 0) { return $els[0] }
        }
        Start-Sleep -Milliseconds $PollIntervalMs
    }
    return $null
}

function Start-PhoneLink {
    <#
    .SYNOPSIS
        Launches Phone Link if not already running, returns the window element.
    #>
    $win = Find-PhoneLinkWindow
    if ($win) { return $win }

    Start-Process "explorer.exe" "ms-phone:"
    Start-Sleep -Seconds 3

    for ($i = 0; $i -lt 10; $i++) {
        $win = Find-PhoneLinkWindow
        if ($win) { return $win }
        Start-Sleep -Seconds 1
    }
    return $null
}

function Get-PhoneLinkConnectionSnapshot {
    param(
        [System.Windows.Automation.AutomationElement]$Window,
        [int]$MaxDepth = 8
    )

    $allElements = Get-AllDescendants -Element $Window -MaxDepth $MaxDepth
    $statusTexts = @()

    foreach ($el in $allElements) {
        try {
            $name = Normalize-UiText $el.Current.Name
            $ctrlType = $el.Current.ControlType.ProgrammaticName -replace '^ControlType\.', ''

            if ($name -and $ctrlType -eq "Text" -and $name.Length -gt 2) {
                $statusTexts += @{
                    text       = $name
                    type       = $ctrlType
                    automation = Normalize-UiText $el.Current.AutomationId
                }
            }
        } catch { continue }
    }

    $connected = $false
    $phoneName = ($statusTexts | Where-Object { $_.automation -eq "PhoneNameTextBlock" } | Select-Object -First 1).text
    if (-not $phoneName) { $phoneName = "" }

    $statusMsg = ($statusTexts | Where-Object {
        $_.automation -eq "ConnectivityCardOpenButton" -or
        $_.automation -eq "ConnectivityStatusTextBlock" -or
        $_.text -match '(?i)(connesso|connected|disconnesso|disconnected)'
    } | Select-Object -First 1).text
    if (-not $statusMsg) { $statusMsg = "" }

    if ($statusMsg -match '(?i)\b(connected|connesso|collegato)\b') {
        $connected = $true
    } elseif ($statusMsg -match '(?i)\b(disconnected|disconnesso|non collegato)\b') {
        $connected = $false
    }

    foreach ($st in $statusTexts) {
        $t = $st.text

        if (-not $phoneName -and $t -match "(?i)(samsung|galaxy|pixel|oneplus|xiaomi|huawei|oppo|iphone|motorola|nokia|redmi|realme|poco|nothing)") {
            $phoneName = $t
        }

        if (-not $statusMsg -and $st.automation -match "(?i)(connect|status)") {
            $statusMsg = $t
        }

        if ($t -match '^(?i)(connected|connesso|collegato)$') {
            $connected = $true
            if (-not $statusMsg) { $statusMsg = $t }
        }

        if ($t -match '^(?i)(disconnected|disconnesso|non collegato)$') {
            $connected = $false
            if (-not $statusMsg) { $statusMsg = $t }
        }
    }

    if (-not $statusMsg) {
        $statusMsg = if ($connected) { "Connected" } else { "Unknown" }
    }

    return [PSCustomObject]@{
        connected  = $connected
        status     = $statusMsg
        phone_name = $phoneName
        ui_texts   = @($statusTexts | Select-Object -First 20)
    }
}

# Export utility: convert results to JSON for the MCP server
function ConvertTo-PlainMcpData {
    param([AllowNull()]$InputData)

    if ($null -eq $InputData) {
        return $null
    }

    if ($InputData -is [string] -or $InputData -is [char]) {
        return Normalize-UiText ([string]$InputData)
    }

    if (
        $InputData -is [bool] -or
        $InputData -is [byte] -or
        $InputData -is [sbyte] -or
        $InputData -is [int16] -or
        $InputData -is [uint16] -or
        $InputData -is [int32] -or
        $InputData -is [uint32] -or
        $InputData -is [int64] -or
        $InputData -is [uint64] -or
        $InputData -is [single] -or
        $InputData -is [double] -or
        $InputData -is [decimal] -or
        $InputData -is [datetime]
    ) {
        return $InputData
    }

    if ($InputData -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in $InputData.Keys) {
            $result[[string]$key] = ConvertTo-PlainMcpData $InputData[$key]
        }
        return [PSCustomObject]$result
    }

    if ($InputData -is [System.Collections.IEnumerable] -and -not ($InputData -is [string])) {
        $items = foreach ($item in $InputData) {
            ConvertTo-PlainMcpData $item
        }
        return ,@($items)
    }

    $properties = @(
        $InputData.PSObject.Properties | Where-Object {
            $_.MemberType -in @("NoteProperty", "Property", "AliasProperty")
        }
    )

    if ($properties.Count -gt 0) {
        $result = [ordered]@{}
        foreach ($property in $properties) {
            try {
                $result[$property.Name] = ConvertTo-PlainMcpData $property.Value
            } catch {
                $result[$property.Name] = Normalize-UiText $_.Exception.Message
            }
        }
        return [PSCustomObject]$result
    }

    return Normalize-UiText ($InputData.ToString())
}

function ConvertTo-McpJson {
    param([AllowNull()]$Data)

    try {
        $plainData = ConvertTo-PlainMcpData $Data
        return ($plainData | ConvertTo-Json -Depth 20 -Compress -ErrorAction Stop)
    } catch {
        $fallback = [PSCustomObject]@{
            error = Normalize-UiText $_.Exception.Message
        }
        return ($fallback | ConvertTo-Json -Depth 5 -Compress -ErrorAction Stop)
    }
}
