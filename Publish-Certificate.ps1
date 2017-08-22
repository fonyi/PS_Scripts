#For the ultimate in laziness. This script will take a .p7b for a user's public encryption cert and add it to their AD attributes for the GAL.
<#
if (-not(Get-PSDrive AD)) {
$creds = Get-Credential
 New-PSDrive -PSProvider ActiveDirectory -Name AD -Server "ad.server.com" -Credential $creds  -Root "//RootDSE/" -Scope Global
}
#>
import-module activedirectory
Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "P7B (*.p7b)| *.p7b"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}
$user = read-host "Enter user's email address"
[string]$un = get-aduser -ldapfilter "(mail=$user)" -Properties samaccountname | Select-Object -Property samaccountname
[string]$sn = get-aduser -ldapfilter "(mail=$user)" -Properties sn | Select-Object -Property sn
$un=[regex]::Match($un,'=(.*?)}').captures.groups[1].value
$sn=[regex]::Match($sn,'=(.*?)}').captures.groups[1].value
write-host $un
$inputfile = Get-FileName "C:\temp"
Import-Certificate -Filepath $inputfile -CertStoreLocation Cert:\CurrentUser\My |Out-Null
$thumb = (Get-ChildItem -Path cert:\CurrentUser\My | where-object {$_.subject -like "*$sn*"}).Thumbprint;
write-host $thumb
$cert = "Cert:\CurrentUser\my\$thumb"
write-host $cert
Export-certificate -Cert $cert -FilePath $PsScriptRoot\out.cer -Type CERT
$cert1 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate $PSScriptRoot\out.cer
Set-ADUser $un -Certificates @{Replace=$cert1}
Remove-Item -Path $cert
Remove-Item $PsScriptRoot\out.cer
write-host "DONE"
write-host "Press any key to exit"
$x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
