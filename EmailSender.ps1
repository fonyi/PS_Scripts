#Script will take a list of emails separated by a return and send the person a predefined email with a hashed vaule of their SAMAccount name appended to the end of a URL that is listed in the message.
#Created by Shane Fonyi 7/20/2016
$inputfile = Get-FileName "C:\temp"
$Users = Get-Content $inputfile
$smtpServer = Read-Host -Prompt 'Enter the email server'
$smtpFrom = Read-Host -Prompt 'Enter the sender address'
$messageSubject = Read-Host -Prompt 'Enter an email subject'
$username = Read-Host -Prompt 'Enter username for email server authentication'
$password = Read-Host -Prompt 'Enter password for email server authentication'
Foreach($User in $Users)
{
 $onlineID =  get-aduser -ldapfilter "(mail=$User)" -property samaccountname | Select -ExpandProperty samaccountname
 $bytes = [System.Text.Encoding]::Unicode.GetBytes($onlineID)
 $EncodedText = [Convert]::ToBase64String($bytes) 
 $message = New-Object System.Net.Mail.MailMessage $smtpFrom, $User
 $message.Subject = $messageSubject
 $message.IsBodyHTML = $true
 $message.Body = "I am a message with a malicious link. Please login to http://fakewebsite.com/?$EncodedText"
 $smtp = New-Object Net.Mail.SmtpClient($smtpServer)
 $smtp.EnableSsl = $true
 $smtp.Credentials = New-Object System.Net.NetworkCredential($username, $password);
 $smtp.Send($message)
}
Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "TXT (*.txt)| *.txt"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}
exit
