#Script takes a list of email addresses that are separted by a return and returns a CSV with the user's online ID, their AD Display Name, title and department.
$inputfile = Get-FileName "C:\temp"
$Users = Get-Content $inputfile
$result=@()
$todaysdate = get-date -date $(get-date).adddays(+0) -format yyyyMMdd
Foreach($User in $Users)
{
$result += get-aduser -ldapfilter "(mail=$User)" -property displayname,mail,title,department | Select-Object -Property displayname,mail,title, department
}$result|
Export-Csv -NoTypeInformation "$PSScriptRoot\output$todaysdate.csv"
Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "TXT (*.TXT)| *.TXT"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
} 
exit
