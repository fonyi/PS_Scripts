#Script takes a list of online IDs that separted by a return and returns a CSV with the user's online ID and their AD Display Name.
$Users = Get-Content 'C:\Users\s223f985\Desktop\PS Scripts\username.txt'
$result=@()
Foreach($User in $Users)
{
$result += get-aduser -ldapfilter "(samaccountname=$User)" -property samaccountname,displayname,mail | Select-Object -Property samaccountname,displayname,mail
}$result|
Export-Csv -NoTypeInformation 'C:\Users\s223f985\Desktop\PS Scripts\fullname.csv'
exit