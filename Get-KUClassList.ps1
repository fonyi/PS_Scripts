$schools = Invoke-WebRequest -Uri "https://credittransfer.ku.edu/api/schools-for/all"
$schools = ConvertFrom-Json $schools
foreach ($school in $schools){
    $id = $school.id
    $courses = Invoke-WebRequest -Uri "https://credittransfer.ku.edu/api/courses-for/$id"
    $output = ConvertFrom-Json $courses
    $output | Export-Csv -Path $PSScriptRoot/kuclasslist.csv -Append
    Start-Sleep -Seconds 1
}
