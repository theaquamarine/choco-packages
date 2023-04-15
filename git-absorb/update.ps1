param (
    [switch]$NoCheckChocoVersion
)

Import-Module AU

function global:au_SearchReplace {
   @{
        "$($Latest.PackageName).nuspec" = @{
            "(\<releaseNotes\>).*?(\</releaseNotes\>)" = "`${1}$($Latest.ReleaseNotes)`$2"
        }

        ".\tools\VERIFICATION.txt" = @{
          "(?i)(Release:\s*).*"            = "Release: $($Latest.ReleaseNotes)"
          "(?i)(Asset:\s*).*" = "Asset: $($Latest.URL64)"
          "(?i)(Checksum:\s*).*"        = "Checksum: $($Latest.Checksum64)"
        }
    }
}

function global:au_BeforeUpdate {
    $url = [Uri]$latest.URL64
    $archiveName = $url.Segments[-1]
    $file = $archiveName

    Invoke-WebRequest $latest.URL64 -OutFile $file

    tar -xf $file
    $folder = $file -replace '\.tar\.gz$'

    $Latest.Checksum64 = Get-FileHash (Join-Path $folder 'git-absorb.exe') -Algorithm SHA512 | Select-Object -ExpandProperty Hash

    Move-Item -Path (Join-Path $folder 'git-absorb.exe') -Destination (Join-Path $PSScriptRoot 'tools') -Force
    Move-Item -Path (Join-Path $folder 'LICENSE.md') -Destination (Join-Path $PSScriptRoot 'tools') -Force
    
    #region readme
    # nuspec descriptions must be <4k chars, so remove some sections from readme
    # Move-Item -Path  -Destination $PSScriptRoot -Force
    $file = (Join-Path $folder 'README.md')
    $toRemove = 'Installing', 'Compiling from Source', 'How it works (roughly)', 'Configuration', 'TODO'

    $sections = Select-String -Path $file -Pattern '^(?:#{1,2}\s+)(?<section>.*$)' | select @{n='Name';e={$_.Line -replace '^#*\s*'}}, @{n='Start';e={$_.LineNumber-1}}

    for ($i = 0; $i -lt $sections.Length; $i++) {
        Add-Member -InputObject $sections[$i] -MemberType NoteProperty -Name End -Value (($sections[$i+1].Start)-1)
    }

    $lines = $sections | ? Name -NotIn $toRemove | % {(Get-Content $file)[($_.Start)..($_.End)]} 

    # join manually and use -NoNewLine to avoid trailing newline
    Set-Content (Join-Path $PSScriptRoot README.md) -Value ($lines -join([System.Environment]::NewLine)) -NoNewline -Encoding utf8
    #endregion readme

    Remove-Item *.tar.gz
    Remove-Item -Recurse $folder
}

function global:au_GetLatest {
    $res = Invoke-RestMethod https://api.github.com/repos/tummychow/git-absorb/releases/latest

    $version = $res.name
    $releaseNotes = $res.html_url
    $url = $res.assets | Where-Object name -like 'git-absorb-*x86_64-pc-windows-msvc.tar.gz' | Select-Object -ExpandProperty browser_download_url

    return @{
        URL64        = $url
        Version      = $version
        ReleaseNotes = $releaseNotes
    }
}

Push-Location $PSScriptRoot
update -ChecksumFor none -NoCheckChocoVersion:$NoCheckChocoVersion
Pop-Location
