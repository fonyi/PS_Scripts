#Script takes a list of email addresses that are separted by a return and returns a CSV with the user's online ID, their AD Display Name, title and department.
Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "TXT (*.TXT)| *.TXT"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
} $inputfile = Get-FileName "C:\temp"
$Users = Get-Content $inputfile
$result=@()
$todaysdate = get-date -date $(get-date).adddays(+0) -format yyyyMMddhhmmss
Foreach($User in $Users)
{
$result += get-aduser -ldapfilter "(mail=$User)" -property givenname,sn,title,mail | Select-Object -Property givenname,sn,mail,title
}$result|
Export-Csv -NoTypeInformation "$PSScriptRoot\output$todaysdate.csv"

exit