function Get-CredentialCachable {
param(
    [Parameter(Mandatory=$true,Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]
    $ResourceName,
    [Parameter(Mandatory=$true,Position=2)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Username,
    [Parameter(Mandatory=$false,Position=1)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Label,
    [switch]$Force
)
BEGIN {
    # PassowrdVault
    [void][Windows.Security.Credentials.PasswordVault,Windows.Security.Credentials,ContentType=WindowsRuntime]
    $passwordVault = new-object Windows.Security.Credentials.PasswordVault -ea 1
    $ret = $null
    # -NonInteractive
    $isNonInteractiveMode = [bool]([Environment]::GetCommandLineArgs() -match '-noni')
    # Params
    if (!$Label) { $Label = "$($ResourceName):$($UserName)" }
}
PROCESS {
    $cachedCred = $null
    try {
        write-verbose "Checking $ResourceName for user $Username"
        $cachedCred = $passwordVault.Retrieve($ResourceName, $Username)
    }
    catch {
        write-verbose $_.Exception.Message
    }
    if ($Force -or !$cachedCred) {
        if (!$isNonInteractiveMode) {
            write-verbose "Storing new credentials"
            # Prompt
            $cred = Get-Credential -Username $Username -Message "Resource: $ResourceName"
            $credUserStr = ''
            if ($cred.GetNetworkCredential().Domain) {
                $credUserStr += "$($cred.GetNetworkCredential().Domain)\"
            }
            $credUserStr += $cred.GetNetworkCredential().Username
            # Store
            $pwCred = new-object Windows.Security.Credentials.PasswordCredential -ea 1 -ArgumentList $ResourceName,$credUserStr,($cred.GetNetworkCredential().Password)
            if (!$?) { throw "Cannot create password credential" }
            $passwordVault.Add($pwCred)
            if (!$?) { throw "Cannot store password credential" }
            # Return PsCredential
            $ret = $cred
        } else {
            write-warning "You cannot store new credentials in -noninteractive mode"
        }
    } elseif($cachedCred) {
        write-verbose "Converting cached cred to PsCred"
        # # Return PsCredential
        $cachedCred.RetrievePassword()
        $ret = New-Object System.Management.Automation.PSCredential ($cachedCred.UserName, (ConvertTo-SecureString $cachedCred.Password -AsPlainText -Force))
    }
}
END {
    return $ret
}}
