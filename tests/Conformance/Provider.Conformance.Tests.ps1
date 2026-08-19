BeforeAll {
    $json = $env:PSDRAWIO_CONFORMANCE_MANIFEST_JSON
    if ([string]::IsNullOrWhiteSpace($json)) {
        $json = '{"PrivateData":{"PSDrawIO":{"ContractVersion":1,"ProviderName":"DefaultFixture","Capabilities":["Shapes"],"Shapes":{}}}}'
    }
    $manifest = $json | ConvertFrom-Json
    $drawIO = $manifest.PrivateData.PSDrawIO
}

Describe 'PS.DrawIO provider contract conformance' {
    It 'declares a contract version' {
        $drawIO.ContractVersion | Should -BeGreaterOrEqual 1
    }

    It 'declares a valid provider name' {
        $drawIO.ProviderName | Should -Match '^[A-Z][A-Za-z0-9]+$'
    }

    It 'declares at least one capability' {
        @($drawIO.Capabilities).Count | Should -BeGreaterThan 0
    }

    It 'declares a Shapes map' {
        $drawIO.PSObject.Properties.Name | Should -Contain 'Shapes'
    }
}
