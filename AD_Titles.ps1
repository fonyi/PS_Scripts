#Script takes a list of email addresses that are separted by a return and returns a CSV with the user's online ID, their AD Display Name, title and department.
$Users = Get-Content 
$result=@()
Foreach($User in $Users)
{
$result += get-aduser -ldapfilter "(mail=$User)" -property displayname,mail,title,department | Select-Object -Property displayname,mail,title, department
}$result|
Export-Csv -NoTypeInformation 'C:\Users\$USER\Desktop\title.csv'
exit
