#Script takes a list of online IDs that separted by a return and returns a CSV with the user's online ID and their AD Display Name.
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
$todaysdate = get-date -date $(get-date).adddays(+0) -format yyyyMMdd
Foreach($User in $Users)
{
$result += get-aduser -ldapfilter "(samaccountname=$User)" -property samaccountname,displayname,mail | Select-Object -Property samaccountname,displayname,mail
}$result|
Export-Csv -NoTypeInformation "$PSScriptRoot\whois$todaysdate.csv"
exit
