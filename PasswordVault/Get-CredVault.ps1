function Get-CredVault {
param()
BEGIN {
    # PassowrdVault
    [void][Windows.Security.Credentials.PasswordVault,Windows.Security.Credentials,ContentType=WindowsRuntime]
    $passwordVault = new-object Windows.Security.Credentials.PasswordVault -ea 1
}
PROCESS {
    $passwordVault.RetrieveAll()
}}
