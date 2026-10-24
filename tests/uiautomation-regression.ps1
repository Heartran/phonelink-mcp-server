# Run with Windows PowerShell 5.1 or PowerShell 7:
# powershell -NoProfile -File tests/uiautomation-regression.ps1
# Test production function bodies with synthetic UI elements, without opening Phone Link.
$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '../scripts/uiautomation-core.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
foreach ($name in @('Normalize-UiText', 'Get-ElementInfo', 'Get-PhoneLinkConnectionSnapshot')) {
    $fn = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }, $true)
    if (-not $fn) { throw "Missing function: $name" }
    # Only substitute the UIAutomation parameter type so plain fixture objects can be passed.
    $definition = $fn.Extent.Text.Replace('[System.Windows.Automation.AutomationElement]', '[object]')
    . ([scriptblock]::Create($definition))
}
function Assert($condition, $message) { if (-not $condition) { throw $message } }
function Get-AllDescendants { param($Element, $MaxDepth) return $script:elements }
function New-Text($text, $id) {
    [pscustomobject]@{ Current = [pscustomobject]@{
        Name = $text; AutomationId = $id
        ControlType = [pscustomobject]@{ ProgrammaticName = 'ControlType.Text' }
    } }
}
$cases = @(
    @('已连接', $true), @('已連線', $true),
    @('未连接', $false), @('未連線', $false),
    @('已断开', $false), @('已中斷連線', $false),
    @('Connected', $true), @('Disconnected', $false),
    @('Connesso', $true), @('Disconnesso', $false)
)
$count = 0
foreach ($case in $cases) {
    foreach ($id in @('ConnectivityStatusTextBlock', 'UnrecognizedStatusId')) {
        $script:elements = @((New-Text 'Test Phone' 'PhoneNameTextBlock'), (New-Text $case[0] $id))
        $result = Get-PhoneLinkConnectionSnapshot -Window ([pscustomobject]@{})
        Assert ($result.connected -eq $case[1]) "Wrong connected state for $($case[0]) / $id"
        Assert ($result.status -eq $case[0]) "Missing localized status for $($case[0]) / $id"
        $count++
    }
}
$ValuePattern = $null
foreach ($number in @([double]::PositiveInfinity, [double]::NegativeInfinity, [double]::NaN, 12.6, -5.2, 0)) {
    $element = [pscustomobject]@{ Current = [pscustomobject]@{
        Name = 'Synthetic element'; AutomationId = 'test'; ClassName = 'test'; IsEnabled = $true
        ControlType = [pscustomobject]@{ ProgrammaticName = 'ControlType.Text' }
        BoundingRectangle = [pscustomobject]@{ X = $number; Y = $number; Width = $number; Height = $number }
    } }
    $result = Get-ElementInfo -Element $element
    Assert (-not $result.ContainsKey('Error')) 'Failed to extract synthetic element'
    $roundTrip = $result | ConvertTo-Json -Depth 5 -Compress | ConvertFrom-Json
    foreach ($field in @('X', 'Y', 'Width', 'Height')) {
        if ([double]::IsInfinity($number) -or [double]::IsNaN($number)) {
            Assert ($null -eq $roundTrip.BoundingRect.$field) "Non-finite $field must serialize as null"
        } else {
            Assert ($roundTrip.BoundingRect.$field -eq [math]::Round($number)) "Finite $field changed"
        }
    }
    $count++
}
Write-Output "Passed $count regression cases (connection states and JSON-safe bounds)."
