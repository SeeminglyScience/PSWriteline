Import-LocalizedData -BindingVariable Strings -FileName Strings -ErrorAction Ignore

$script:PSReadLineSingleton = `
    [Microsoft.PowerShell.PSConsoleReadLine].
        GetField('_singleton', 60).
        GetValue($null)

# Include all function files.
Get-ChildItem `
    $PSScriptRoot\Public\*.ps1,
    $PSScriptRoot\Private\*.ps1,
    $PSScriptRoot\KeyHandlers\*.ps1 |
    ForEach-Object { . $PSItem.FullName }

# Export only the functions using PowerShell standard verb-noun naming.
# Be sure to list each exported functions in the FunctionsToExport field of the module manifest file.
# This improves performance of command discovery in PowerShell.
Export-ModuleMember -Function *-*

