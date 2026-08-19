class PSDrawIOProviderDeclaration {
    [string]$ProviderName
    [int]$ContractVersion
    [string[]]$Capabilities
    [hashtable]$Shapes
    [hashtable]$Metadata

    PSDrawIOProviderDeclaration() {
        $this.Capabilities = @()
        $this.Shapes = @{}
        $this.Metadata = @{}
    }
}
