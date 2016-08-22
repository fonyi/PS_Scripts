#Script takes a display name in the format "Lastname, Firstname" WITHOUT quotes separated by a return and resturns a CSV with Online ID and primary email address.
Import-Module activedirectory
Function Get-FileName($initialDirectory)
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.filter = "TXT (*.txt)| *.txt"
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}
$todaysdate = get-date -date $(get-date).adddays(+0) -format yyyyMMddhhmm
$inputfile = Get-FileName "C:\temp"
Get-Content $inputfile |
ForEach-Object{

get-aduser -ldapfilter "(displayname=$_*)" -property samaccountname,displayname,mail | Select-Object -Property samaccountname,mail

} |
Export-Csv -NoTypeInformation "$PSScriptRoot\output$todaysdate.csv"
exit
