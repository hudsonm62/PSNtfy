[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'testing suite')] param()

Describe "PSNtfy Module validity" {
    BeforeAll {
        $root = Resolve-Path (Join-Path -Path $PSScriptRoot -ChildPath "../../src/PSNtfy")
        $psm1File = Get-Item -Path (Join-Path $root 'PSNtfy.psm1')
        $psd1File = Get-Item -Path (Join-Path $root 'PSNtfy.psd1')
    }
    Context "Module Manifest Tests" {
        It "should validate manifest" {
            $x = Test-ModuleManifest -Path $psd1File.FullName
            $x | Should -Not -Be $null
            $x | Should -BeOfType [System.Management.Automation.PSModuleInfo]
        }
        It "should explicitly psm1" {
            $x = Test-ModuleManifest -Path $psd1File.FullName
            $x.RootModule | Should -Not -BeNullOrEmpty
            $x.RootModule | Should -Match ".*\.psm1$"
        }
        It "should contain a valid version" {
            $x = Test-ModuleManifest -Path $psd1File.FullName
            $x.Version | Should -Not -BeNullOrEmpty
            $x.Version | Should -Match "^\d+\.\d+\.\d+(\.\d+)?$"
        }
        It "should contain a valid GUID" {
            $x = Test-ModuleManifest -Path $psd1File.FullName
            $x.Guid | Should -Not -BeNullOrEmpty
            $x.Guid | Should -BeOfType [System.Guid]
            $x.Guid | Should -Not -Be [guid]::Empty
        }
        It "should contain a valid author" {
            $x = Test-ModuleManifest -Path $psd1File.FullName
            $x.Author | Should -Not -BeNullOrEmpty
        }
        It "should contain a valid description" {
            $x = Test-ModuleManifest -Path $psd1File.FullName
            $x.Description | Should -Not -BeNullOrEmpty
        }
    }
    Context "Module File Tests" {
        It "should load without errors" {
            Import-Module -Name $root -Force -ErrorAction Stop
            $module = Get-Module -Name PSNtfy
            $module | Should -Not -Be $null
        }
        It "should have correct version after import" {
            Import-Module -Name $root -Force -ErrorAction Stop
            $module = Get-Module -Name PSNtfy
            $module.Version.ToString() | Should -Be ( (Test-ModuleManifest -Path $psd1File.FullName).Version.ToString() )
        }
        It "should have exported functions" {
            Import-Module -Name $root -Force -ErrorAction Stop
            $module = Get-Module -Name PSNtfy
            $exportedFunctions = $module.ExportedCommands.Values | Where-Object CommandType -eq 'Function'
            $exportedFunctions.Count | Should -BeGreaterThan 0
        }
    }
}
