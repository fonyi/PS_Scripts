#Script takes a display name in the format "Lastname, Firstname" WITHOUT quotes separated by a return and resturns a CSV with Online ID and primary email address.
Import-Module activedirectory
Get-Content 'A:\Desktop\PS Scripts\users.txt' |
ForEach-Object{

get-aduser -ldapfilter "(displayname=$_)" -property samaccountname,displayname,mail | Select-Object -Property samaccountname,mail

} |

Export-Csv -NoTypeInformation 'A:\Desktop\PS Scripts\results.txt'
exit