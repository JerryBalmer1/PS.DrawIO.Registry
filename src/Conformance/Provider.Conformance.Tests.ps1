BeforeAll {
    if ([string]::IsNullOrWhiteSpace($env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON)) {
        throw "PSDRAWIO_CONFORMANCE_MANIFEST_JSON is required to run provider conformance."
    }
    $script:conformanceManifest = $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON | ConvertFrom-Json
    $script:drawIO = $script:conformanceManifest.PrivateData.PSDrawIO
}

Describe 'PS.DrawIO provider contract conformance' {
    It 'declares a contract version' {
        $script:drawIO.ContractVersion | Should -BeGreaterOrEqual 1
    }

    It 'declares a valid provider name' {
        $script:drawIO.ProviderName | Should -Match '^[A-Z][A-Za-z0-9]+$'
    }

    It 'declares at least one capability' {
        $script:drawIO.PSObject.Properties.Name | Should -Contain 'Capabilities'
        @($script:drawIO.Capabilities).Count | Should -BeGreaterThan 0
    }

    It 'declares a Shapes map' {
        $script:drawIO.PSObject.Properties.Name | Should -Contain 'Shapes'
    }
}
