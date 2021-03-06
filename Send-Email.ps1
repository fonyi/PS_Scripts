#Script will take a list of emails separated by a return and send the person a predefined email with a hashed vaule of their SAMAccount name appended to the end of a URL that is listed in the message.
#Created by Shane Fonyi 7/20/2016
Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "TXT (*.txt)| *.txt"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}
$inputfile = Get-FileName "C:\temp"
$Users = Get-Content $inputfile
$smtpServer = Read-Host -Prompt 'Enter the email server'
$port = Read-Host -Prompt 'Enter port for email server (Default is 25)'
$smtpFrom = Read-Host -Prompt 'Enter the sender address'
$fromName = Read-Host -Prompt 'Enter sender name'
$from = "$fromName <$smtpFrom>"
$messageSubject = Read-Host -Prompt 'Enter an email subject'
$username = Read-Host -Prompt 'Enter username for email server authentication'
$password = Read-Host -Prompt 'Enter password for email server authentication' -AsSecureString
Foreach($User in $Users)
{
 $onlineID =  get-aduser -ldapfilter "(mail=$User)" -property samaccountname | Select -ExpandProperty samaccountname
 $firstname = get-aduser -ldapfilter "(mail=$User)" -property GivenName | Select -ExpandProperty GivenName
 $bytes = [System.Text.Encoding]::Unicode.GetBytes($onlineID)
 $EncodedText = [Convert]::ToBase64String($bytes) 
 $link = '<a href="http://clickhere.college.edu/?$EncodedText">here</a>'
 $link = $ExecutionContext.InvokeCommand.ExpandString($link) 
 $message = New-Object System.Net.Mail.MailMessage $from, $User
 $message.Subject = $messageSubject
 $message.IsBodyHTML = $true
 $message.Body = "Dear $firstname<BR><BR><B><H4>Your account has been compromised!</H4><P></B>Please go $link to reset your password.<BR><BR>Sincerely,<BR><BR>IT Customer Service<BR>University of City<BR>555-555-5555<BR>it@college.edu</A></P>"
 $smtp = New-Object Net.Mail.SmtpClient($smtpServer)
 $smtp.Port =$port
 $smtp.EnableSsl = $true
 $smtp.Credentials = New-Object System.Net.NetworkCredential($username, $password);
 $smtp.Send($message)
}
exit
