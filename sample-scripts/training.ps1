<powershell>

Set-ExecutionPolicy Unrestricted -Force

write-host "Configuring timezone"
tzutil.exe /s "{timezone}"

write-host "Creating default directories"
if (-Not (Test-Path "C:\TempDownloads")) { New-Item -ItemType directory -Path C:\TempDownloads | Out-Null }
if (-Not (Test-Path "C:\Firmstep")) { New-Item -ItemType directory -Path C:\Firmstep | Out-Null }

$errors = ""

{snip_win_utilities}

{snip_win_monitoring}

{snip_win_localadmin}

write-host "Downloading and installing SSMS"
(New-Object System.Net.WebClient).DownloadFile("https://download.microsoft.com/download/4/2/A/42A5A62F-9290-45CB-84CF-6A4E17888FDE/SQLManagementStudio_x64_ENU.exe", "C:\TempDownloads\ssms.exe")
if (Test-Path C:\TempDownloads\ssms.exe){
    C:\TempDownloads\ssms.exe /QUIET /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SSMS /ACTION=Install | Out-Null
} else {
    $errors += "SSMS not found. "
}

write-host "Downloading and installing SQLEXPR_x64_ENU.exe" 
(New-Object System.Net.WebClient).DownloadFile("https://download.microsoft.com/download/0/4/B/04BE03CD-EAF3-4797-9D8D-2E08E316C998/SQLEXPR_x64_ENU.exe", "C:\TempDownloads\SQLEXPR_x64_ENU.exe") 
if (Test-Path C:\TempDownloads\SQLEXPR_x64_ENU.exe) { 
    C:\TempDownloads\SQLEXPR_x64_ENU.exe /Q /Action=Install /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLEngine,BC,Conn /InstanceName=MSSQLSERVER /SECURITYMODE=SQL "/SAPWD={adminpassword}" /TCPENABLED=1 /SQLSVCACCOUNT=SYSTEM | Out-Null 
} else { 
    $errors += "SQLEXPR_x64_ENU not found. " 
} 

if ("{environment}" -eq "test") {
    {snip_win_domainjoin}
}

if ($errors) {
    Send-MailMessage -From "{name}@firmstep.com" -To "auckland-team@firmstep.com" -Subject "{name} Automation Error [{environment}]" -SmtpServer "smtp.firmstep.com" -Body "$errors"
}

Write-Host "Installing IIS"
Import-Module ServerManager
Add-WindowsFeature -Name Web-Common-Http,Web-Net-Ext,Web-CGI,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Http-Logging,Web-Filtering,Web-Performance,Web-Mgmt-Console -IncludeAllSubFeature | Out-Null

# Remove default content
Remove-Item "C:\inetpub\wwwroot\*.*"

# Download and install SSL certificate
Copy-S3Object -AccessKey {s3_key} -SecretKey {s3_secret} -BucketName {s3_bucket} -Key Configuration/Certificates/{environment}/certificate.pfx -LocalFile C:\TempDownloads\certificate.pfx
C:\Windows\System32\certutil.exe -f -p {sslcertpassword} -importpfx "C:\TempDownloads\certificate.pfx"
$cert = Get-ChildItem -Path Cert:\LocalMachine\My | Select-Object -First 1
New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https
New-Item -Path IIS:\SslBindings\0.0.0.0!443 -Value $cert

# Download latest code from GitHub
Invoke-RestMethod -Uri https://api.github.com/repos/Firmstep/FS-TrainingMaterials/zipball/{gitbranch} -Headers @{"Authorization" = "token {github}"} -OutFile C:/TempDownloads/Training.zip
c:\Program` Files\7-Zip\7z.exe x c:\TempDownloads\Training.zip -oC:\inetpub\wwwroot\ | Out-Null

# Create Build file in webroot folder
new-item "C:/inetpub/wwwroot/build.txt" -type File -force -value "Build: {name} {build}"

# Cleanup
Remove-Item "C:\Users\Default\Desktop\*.*"
Remove-Item "C:\TempDownloads" -Recurse -Force

Stop-Computer

</powershell>
