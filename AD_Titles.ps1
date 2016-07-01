#Script takes a list of online IDs that separted by a return and returns a CSV with the user's online ID and their AD Display Name.
$Users = Get-Content 'C:\Users\s223f985\Desktop\PS Scripts\email.txt'
$result=@()
Foreach($User in $Users)
{
$result += get-aduser -ldapfilter "(mail=$User)" -property displayname,mail,title,department | Select-Object -Property displayname,mail,title, department
}$result|
Export-Csv -NoTypeInformation 'C:\Users\s223f985\Desktop\PS Scripts\title.csv'
exit