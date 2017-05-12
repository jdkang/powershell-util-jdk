function Get-GithubLatestRelease {
param(
    [string]
    $Repo,
    [Parameter(Mandatory=$true,ParameterSetname='AssetByName')]
    [ValidateNotNullOrEmpty()]
    [string]
    $AssetName,
    [Parameter(Mandatory=$true,ParameterSetname='zipball')]
    [switch]$ZipFile,
    [Parameter(Mandatory=$true,ParameterSetname='tarball')]
    [switch]$TargzFile,
    [Parameter(Mandatory=$False)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Destination,
    [Parameter(Mandatory=$true,ParameterSetname='ListAssets')]
    [switch]$ListAssets
)
    $latestReleaseUrl = 'https://api.github.com/repos/{0}/releases/latest' -f $Repo
    $latestReleaseResp = Invoke-RestMethod $latestReleaseUrl -ea 1
    if ($latestReleaseResp) {  
        # List Assets
        if($ListAssets) {
            return $latestReleaseResp.Assets
        }
        # Get Asset Dwonload Url
        write-verbose "latest release: $($latestReleaseResp.Name)"
        $downloadUrl = ''
        $assetNameToFind = ''
        $useWebClientToDownload = $false
        switch($PsCmdlet.ParameterSetname) {
            'AssetByName' {
                $useWebClientToDownload = $true
                write-verbose "Searching for browser URL for Asset $AssetName"
                $downloadUrl = $latestReleaseResp |
                               select -expand assets |
                               where-object { $_.name -eq $AssetName } |
                               select -expand 'browser_download_url'
            }
            'zipball' {
                write-verbose "Using URL from zipball_url"
                $downloadUrl = $latestReleaseResp.'zipball_url'
            }
            'tarball' {
                write-verbose "Using URL from tarball_url"
                $downloadUrl = $latestReleaseResp.'tarball_url'
            }
            default { throw 'unknown ParameterSet' }
        }
        if([string]::IsNullOrEmpty($downloadUrl)) {
            throw "Could not find download url for specified asset"
        }
        # Destination (if blank)
        if (!$Destination) {
            $Destination = [io.path]::GetTempPath()
            if ($AssetName) {
                if ($AssetName -match '\.(?<ext>\w+$)') {
                    $ext = $matches['ext']
                    $Destination += $AssetName.Replace($ext, ($latestReleaseResp.'tag_name' + ".$($ext)"))
                } else {
                    $Destination += $AssetName + $latestReleaseResp.'tag_name'
                }
            } elseif($ZipFile -or $TargzFile) {
                $useExt = ''
                if($ZipFile) { $useExt = '.zip' }
                if($TargzFile) { $useExt = '.tar.gz' }
                $downloadUrlLastPart = $downloadUrl -split '/' |
                                       where-object { $_ } |
                                       select -last 1
                $Destination += $downloadUrlLastPart
                if ($Destination -notlike "*$($useExt)") { $Destination += $useExt }
            } else {
                $Destination += [io.path]::GetRandomFileName()
            }
        }
        # Download
        write-verbose "Downloading $downloadUrl to $Destination"
        $webClient = new-object net.webclient
        try {
            if ($useWebClientToDownload) {
                $webClient.DownloadFile($downloadUrl, $Destination)
            } else {
                Invoke-RestMethod -Method GET -Uri $downloadUrl -OutFile $Destination
            }
            Get-Item $Destination
        }
        catch {
            throw
        }
        finally {
            if($webClient) { $webClient.Dispose() }
        }
    }
}
