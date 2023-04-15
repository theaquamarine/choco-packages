Describe "git-absorb" {
	BeforeDiscovery {
		$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments',
			'notAdministrator', Justification = 'Used outside block')]
		$notAdministrator = -not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
	}

	BeforeAll {
		Import-Module AU
		[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments',
			'nuspec', Justification = 'Used outside block')]
		$nuspec = Join-Path $PSScriptRoot '*.nuspec' | Resolve-Path
	}

	It "has a .nuspec" {
		$nuspec | Should -Not -BeNullOrEmpty
		$nuspec | Should -Exist
	}

	Context "updates" {
		BeforeAll {
			# delete the existing .nupkg
			$nupkg = Join-Path $PSScriptRoot '*.nupkg'
			if ($nupkg) {Remove-item $nupkg}

			# reset the version number to 0.0.0 so there's always something to package
			(Get-Content $nuspec) -replace '<version>[\d\.]*</version>','<version>0.0.0</version>' | Set-Content $nuspec
			[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments',
				'out', Justification = 'Used outside block')]
			$out = . (Join-Path $PSScriptRoot update.ps1) -NoCheckChocoVersion
		}

		It 'updates' {
			$out.Updated | Should -Be $true
		}

		It 'did not error' {
			$out.Error | Should -BeNullOrEmpty
		}

		It 'has a license file' {
			(Join-Path $PSScriptRoot 'tools/LICENSE*') | Should -Exist
		}
		
		It 'has a verification file' {
			(Join-Path $PSScriptRoot 'tools/VERIFICATION*') | Should -Exist
		}
		
		It 'has an executable' {
			(Join-Path $PSScriptRoot 'tools/*.exe') | Should -Exist
		}

		It 'has a description <4k characters' {
			[xml]$xml = Get-Content $nuspec
			$xml.package.metadata.description.InnerText.Length | Should -BeLessThan 4000

		}
		
		It 'created a .nupkg' {
			$nupkg | Should -Exist
		}
	}

	Context "install" -Skip:$notAdministrator {
		It "installs" {
			Test-Package -Install -Nu $PSScriptRoot | Should -Not -Throw
		}

		It "is installed" {
			Get-Command 'git-absorb' | Should -Not -BeNullOrEmpty
		}
	}
	
	Context "uninstall" -Skip:$notAdministrator {
		BeforeAll {
			Get-Command 'git-absorb' -ErrorAction Stop
		}

		It "uninstalls" {
			Test-Package -Uninstall -Nu $PSScriptRoot | Should -Not -Throw
		}

		It "is uninstalled" {
			Get-Command 'git-absorb' -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
		}
	}
}
