Import-Module AU

function global:au_SearchReplace {
   @{
        "$($Latest.PackageName).nuspec" = @{
            "(\<releaseNotes\>).*?(\</releaseNotes\>)" = "`${1}$($Latest.ReleaseNotes)`$2"
        }

        ".\legal\VERIFICATION.txt" = @{
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
    Move-Item -Path (Join-Path $folder 'LICENSE.md') -Destination (Join-Path $PSScriptRoot 'legal') -Force
    Move-Item -Path (Join-Path $folder 'README.md') -Destination $PSScriptRoot -Force

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
update -ChecksumFor none
Pop-Location
