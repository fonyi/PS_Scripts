#Script that prompts for credentials and determines if the credentials are good or not against LDAP.
#Created by Shane Fonyi 7/21/2016
#TODO
##Check for username based off of email alias

#allow for file input and display status in terminal
Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "TXT (*.txt)| *.txt"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

#allow for file input and display status in terminal
$todaysdate = get-date -date $(get-date).adddays(+0) -format yyyyMMddHHmmss
$option = Read-Host -Prompt 'Enter 1 to upload a file in the format username:password or username@domain.com:password or press enter to manually enter creds.'
if ($option -eq "1"){
 $inputfile = Get-FileName "C:\temp"
 $Users = Get-Content $inputfile
 if ($option -eq "1"){
   $writetolog = Read-Host -Prompt 'Enter 1 to log the output to a file or enter to just log to the host'
  }
 Foreach ($User in $Users){
  $UserName,$Password = $User.split(':',2)

  #match regex for password with at least 1 cap, 1 lowercase, 1 number, and 1 special char between 8 and 32 chars. 
  if ($Password -match '^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[#?!@$%^&*-]).{8,32}$'){
  if ($UserName -like '*@*'){
     $pos = $UserName.IndexOf("@")
     $UserName = $UserName.Substring(0,$pos)
   }
  $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
  $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)
  if ($domain.name -eq $null){
    if ($option -eq "1") { Add-Content $PSScriptRoot\log$todaysdate.txt "`nAuthentication failed for $Username"}
    write-host "Authentication failed for $Username"
   }
  else{
    if ($option -eq "1") { Add-Content $PSScriptRoot\log$todaysdate.txt "`nSuccessfully authenticated with user $UserName"}
    write-host "Successfully authenticated with user $UserName"
   }
 }
 else {
  if ($option -eq "1") { Add-Content $PSScriptRoot\log$todaysdate.txt "`nPassword does not meet complexity for $Username"}
  write-host "Password does not meet complexity for $Username"
 }
 }
 Read-Host -Prompt 'Press Enter to exit'
}

#allow for manual entry of credentials
else{
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
}
