function Remove-CredVault {
param(
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    $UserName,
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    $Resource
)
BEGIN {
    # PassowrdVault
    [void][Windows.Security.Credentials.PasswordVault,Windows.Security.Credentials,ContentType=WindowsRuntime]
    $passwordVault = new-object Windows.Security.Credentials.PasswordVault -ea 1
}
PROCESS {
    try {
        $userCred = $passwordVault.Retrieve($Resource, $UserName)
        if ($userCred) {
            $passwordVault.Remove($userCred)
        }
    }
    catch { write-warning "Cannot find $Resource $$UserName" }
}}
