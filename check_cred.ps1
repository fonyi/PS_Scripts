#Simple script that prompts for credentials and determines if the credentials are good or not

#TODO
#allow for file imput and display status in terminal
do{
$cred = Get-Credential #Read credentials
 $username = $cred.username
 $password = $cred.GetNetworkCredential().password

 # Get current domain using logged-on user's credentials
 $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
 $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)

if ($domain.name -eq $null)
{
 write-host "Authentication failed - please verify your username and password."
  $continue = Read-Host -Prompt 'Enter "1" to check again or nothing to exit'
}
else
{
 write-host "Successfully authenticated with user $username"
  $continue = Read-Host -Prompt 'Enter "1" to check again or nothing to exit'
}
}
while($continue -eq "1")
