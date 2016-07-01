#Simple script that prompts for credentials and determines if the credentials are good or not

#TODO
#Create loop
#allow for file imput and display status in terminal
$cred = Get-Credential #Read credentials
 $username = $cred.username
 $password = $cred.GetNetworkCredential().password

 # Get current domain using logged-on user's credentials
 $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
 $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)

if ($domain.name -eq $null)
{
 write-host "Authentication failed - please verify your username and password."
  Read-Host -Prompt "Press Enter to exit"
}
else
{
 write-host "Successfully authenticated with domain $domain.name"
  Read-Host -Prompt "Press Enter to exit"
}
