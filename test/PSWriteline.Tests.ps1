$moduleName = 'PSWriteline'
$manifestPath = "$PSScriptRoot\..\Release\$moduleName\*\$moduleName.psd1"

Describe 'module manifest values' {
    It 'can retrieve manfiest data' {
        $script:manifest = Test-ModuleManifest $manifestPath
    }
    It 'has the correct name' {
        $script:manifest.Name | Should Be $moduleName
    }
    It 'has the correct guid' {
        $script:manifest.Guid | Should Be '90b6b6fb-010f-4ebd-a590-ea31386ba293'
    }
}

