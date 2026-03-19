<#
.SYNOPSIS
    Reads the photo gallery from the Phone Link Photos tab.
.PARAMETER MaxPhotos
    Maximum number of photo entries to extract (default: 25).
#>
param(
    [int]$MaxPhotos = 25
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\uiautomation-core.ps1"

try {
    $win = Find-PhoneLinkWindow
    if (-not $win) {
        $win = Start-PhoneLink
        if (-not $win) {
            ConvertTo-McpJson @{ error = "Cannot find or launch Phone Link"; photos = @() }
            return
        }
    }

    # Navigate to Photos tab
    $tabNames = @("Photos", "Foto", "Fotos", "Bilder")
    $clicked = $false
    foreach ($tabName in $tabNames) {
        $tab = Find-ElementsByName -Root $win -NameContains $tabName -MaxDepth 6 |
               Select-Object -First 1
        if ($tab) {
            Invoke-ElementClick -Element $tab | Out-Null
            Start-Sleep -Seconds 3
            $clicked = $true
            break
        }
    }
    if (-not $clicked) {
        $photoTab = Find-ElementByAutomationId -Root $win -AutomationId "PhotosNavButton"
        if (-not $photoTab) {
            $photoTab = Find-ElementByAutomationId -Root $win -AutomationId "PhotosTab"
        }
        if ($photoTab) {
            Invoke-ElementClick -Element $photoTab | Out-Null
            Start-Sleep -Seconds 3
        }
    }

    Start-Sleep -Seconds 2

    # Scrape photo grid
    $allElements = Get-AllDescendants -Element $win -MaxDepth 12
    $photos = @()

    foreach ($el in $allElements) {
        try {
            $name = $el.Current.Name
            $ctrlType = $el.Current.ControlType.ProgrammaticName -replace '^ControlType\.', ''
            $autoId = $el.Current.AutomationId
            $rect = $el.Current.BoundingRectangle

            if (-not $name) { continue }

            # Photo items are typically Image controls or ListItems with image-like names
            if ($ctrlType -in @("Image", "ListItem", "DataItem", "Button") -and
                ($name -match "\d" -or $name -match "(?i)(photo|foto|image|immagine|screenshot|screen)")) {

                # Skip tiny icons (navigation buttons etc)
                if ($rect.Width -lt 50 -or $rect.Height -lt 50) { continue }

                $photos += @{
                    name          = $name
                    control_type  = $ctrlType
                    automation_id = $autoId
                    bounds        = @{
                        x      = [math]::Round($rect.X)
                        y      = [math]::Round($rect.Y)
                        width  = [math]::Round($rect.Width)
                        height = [math]::Round($rect.Height)
                    }
                }
            }
        } catch { continue }
    }

    $photos = $photos | Select-Object -First $MaxPhotos

    ConvertTo-McpJson @{
        photo_count = $photos.Count
        photos      = $photos
    }
} catch {
    ConvertTo-McpJson @{ error = $_.Exception.Message; photos = @() }
}
