# Root folder for the project
$rootFolder = "C:\git-projects\dcst1005\dcst1005\"

# CSV-file with users
$groups = Import-Csv -Path "$rootFolder\tmp_csv-users-example.csv" -Delimiter ","
