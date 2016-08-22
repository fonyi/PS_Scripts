#Script takes a display name in the format "Lastname, Firstname" WITHOUT quotes separated by a return and resturns a CSV with Online ID and primary email address.
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
$result=@()
$todaysdate = get-date -date $(get-date).adddays(+0) -format yyyyMMddhhmm
Foreach($User in $Users)
{
$Lastname,$Firstname = $User.split(', ',2)
$result += get-aduser -filter { sn -like $Lastname -and givenName -like $Firstname} -property samaccountname,displayname,mail | Select-Object -Property samaccountname,displayname,mail
}$result|
Export-Csv -NoTypeInformation "$PSScriptRoot\whois$todaysdate.csv"
exit
