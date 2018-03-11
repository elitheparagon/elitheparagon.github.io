<powershell>

Set-ExecutionPolicy Unrestricted -Force

function PostSlackMessage {
	param([string]$message)
	$json = @{"channel"="auckland-bot"; "username"="DC Automation [{environment}]"; "text"=$message; "icon_emoji"=":computer:"} | ConvertTo-Json
	Invoke-WebRequest -Method POST -Uri https://hooks.slack.com/services/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 -Body $json
}

if (-Not (Test-Path "C:\TempDownloads")) { New-Item -ItemType directory -Path C:\TempDownloads | Out-Null }

write-host "Configuring timezone"
tzutil.exe /s "{timezone}"

#Get password for Administrator Account
write-host "Configuring Administrator User Account"
$localadmin = [ADSI]"WinNT://$env:computername/Administrator,user"
$localadmin.SetPassword("{adminpassword}")

If (Test-Path C:\Windows\Microsoft.NET\Framework64\v2.0.50727\System.Web.dll) {
	Add-Type -Path C:\Windows\Microsoft.NET\Framework64\v2.0.50727\System.Web.dll
}
Else
{
	Add-Type -Path C:\Windows\Microsoft.NET\Framework64\v4.0.30319\System.Web.dll
}

#Generate SQL Password
$sqlpass = [System.Web.Security.Membership]::GeneratePassword(16,2)  
$pattern = '[^a-zA-Z1-9#@!%^*()]'
$sqlpass = $sqlpass -replace $pattern, '$'

PostSlackMessage "New DC sql pass is: $sqlpass"

Write-Host "Installing IIS"
Import-Module ServerManager
Add-WindowsFeature -Name Web-Common-Http,Web-Net-Ext,Web-CGI,Web-ISAPI-Ext,Web-ISAPI-Filter,Web-Http-Logging,Web-Filtering,Web-Performance,Web-Mgmt-Console,Web-Mgmt-Compat,WAS -IncludeAllSubFeature | Out-Null

#Include SQL server local instance!
write-host "Downloading and installing SQLEXPR_x64_ENU.exe"
(New-Object System.Net.WebClient).DownloadFile("https://download.microsoft.com/download/0/4/B/04BE03CD-EAF3-4797-9D8D-2E08E316C998/SQLEXPR_x64_ENU.exe", "C:\TempDownloads\SQLEXPR_x64_ENU.exe")
if (Test-Path C:\TempDownloads\SQLEXPR_x64_ENU.exe){
C:\TempDownloads\SQLEXPR_x64_ENU.exe /Q /Action=Install /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SQLEngine,BC,Conn /InstanceName=MSSQLSERVER /SECURITYMODE=SQL "/SAPWD=$sqlpass" /TCPENABLED=1 /SQLSVCACCOUNT=SYSTEM | Out-Null
} else {
$errors += "SQLEXPR_x64_ENU not found. "
}

write-host "Downloading and installing SSMS"
(New-Object System.Net.WebClient).DownloadFile("https://download.microsoft.com/download/4/2/A/42A5A62F-9290-45CB-84CF-6A4E17888FDE/SQLManagementStudio_x64_ENU.exe", "C:\TempDownloads\ssms.exe")
if (Test-Path C:\TempDownloads\ssms.exe){
C:\TempDownloads\ssms.exe /QUIET /IACCEPTSQLSERVERLICENSETERMS /FEATURES=SSMS /ACTION=Install | Out-Null
} else {
$errors += "SSMS not found. "
}

write-host "Installing UrlRewrite2"
(New-Object System.Net.WebClient).DownloadFile("http://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi", "C:\TempDownloads\rewrite_amd64.msi")
if (Test-Path C:\TempDownloads\rewrite_amd64.msi){
msiexec /package "C:\TempDownloads\rewrite_amd64.msi" /quiet /passive /qn /norestart /log c:/msi.log | Out-Host
} else {
$errors += "UrlRewrite2 not found. "
}

write-host "Downloading and installing MSSQL ODBC Driver"
(New-Object System.Net.WebClient).DownloadFile("https://download.microsoft.com/download/5/7/2/57249A3A-19D6-4901-ACCE-80924ABEB267/ENU/x64/msodbcsql.msi", "C:\TempDownloads\mssql.msi")
if (Test-Path C:\TempDownloads\mssql.msi){
msiexec /package "C:\TempDownloads\mssql.msi" /quiet /passive /qn /norestart IACCEPTMSODBCSQLLICENSETERMS=YES | Out-Null
} else {
$errors += "MSSQL ODBC Driver not found. "
}

write-host "Downloading and installing 7zip"
(New-Object System.Net.WebClient).DownloadFile("http://www.7-zip.org/a/7z1514-x64.msi", "C:\TempDownloads\7zip.msi")
if (Test-Path C:\TempDownloads\7zip.msi){
msiexec /package "C:\TempDownloads\7zip.msi" /quiet /passive /qn /norestart | Out-Null
} else {
$errors += "7zip not found. "
}

write-host "Downloading and installing Notepad++"
(New-Object System.Net.WebClient).DownloadFile("https://notepad-plus-plus.org/repository/6.x/6.9.2/npp.6.9.2.Installer.exe", "C:\TempDownloads\npp.exe")
if (Test-Path C:\TempDownloads\npp.exe){
C:\TempDownloads\npp.exe /Q /S | Out-Null
} else {
$errors += "Notepad++ not found. "
}

write-host "Downloading and installing AWS CLI Tools"
(New-Object System.Net.WebClient).DownloadFile("https://s3.amazonaws.com/aws-cli/AWSCLI64.msi", "C:\TempDownloads\AWSCLI64.msi")
if (Test-Path C:\TempDownloads\AWSCLI64.msi){
msiexec /package "C:\TempDownloads\AWSCLI64.msi" /quiet /passive /qn /norestart | Out-Null
} else {
$errors += "AWS CLI Tools not found. "
}

write-host "Downloading and installing C++ 2015 Redistributable"
(New-Object System.Net.WebClient).DownloadFile("https://download.microsoft.com/download/9/3/F/93FCF1E7-E6A4-478B-96E7-D4B285925B00/vc_redist.x64.exe", "C:\TempDownloads\vcredist_2015.exe")
if (Test-Path C:\TempDownloads\vcredist_2015.exe){
C:\TempDownloads\vcredist_2015.exe /Q /S | Out-Null
} else {
$errors += "C++ 2015 Redistributable not found. "
}

#PHP install & configuration
write-host "Downloading and installing PHP"
(New-Object System.Net.WebClient).DownloadFile("http://windows.php.net/downloads/releases/archives/php-7.0.15-Win32-VC14-x64.zip", "C:\TempDownloads\php.zip")
if (Test-Path C:\TempDownloads\php.zip){
C:\Program` Files\7-Zip\7z.exe x C:\TempDownloads\php.zip -oc:\PHP | Out-Null
} else {
$errors += "PHP not found. "
}

# Send an email if any errors downloading files
if ($errors) {
	PostSlackMessage $error
	Exit
}

#Verify that SQL Server installation has completed, then create blank database
$connectionString = "Server=localhost;uid=sa;pwd=$sqlpass;"
$connectCount = 0

While (1) {
	Try {
		$connection = New-Object System.Data.SQLClient.SQLConnection($connectionString)
		$connection.Open()
		Break
	}
	Catch {
		# 10m timeout, check once per 10s
		$connectCount++
		Start-Sleep -s (10)
		if ($connectCount -eq 60) {
			PostSlackMessage "DC SQL Server connection failed - automation aborted!"
			Exit
		}
		else {
			PostSlackMessage "DC SQL Server connection error: $($_.Exception.Message), retrying in 10 sec"
		}			
	}
}
$command = New-Object System.Data.SQLClient.SQLCommand("CREATE DATABASE PasswordReset", $connection)
$command.ExecuteNonQuery()

#Retrieve PHP config files
Copy-S3Object -AccessKey {s3_key} -SecretKey {s3_secret} -BucketName {s3_bucket} -Key PHP/cacert.pem -LocalFile C:/PHP/cacert.pem | Out-Null
Copy-S3Object -AccessKey {s3_key} -SecretKey {s3_secret} -BucketName {s3_bucket} -Key PHP/php-Component.ini -LocalFile C:/PHP/php.ini | Out-Null
Copy-S3Object -AccessKey {s3_key} -SecretKey {s3_secret} -BucketName {s3_bucket} -Key PHP/php_pdo_sqlsrv_7_ts_x64.dll -LocalFile C:/PHP/ext/php_pdo_sqlsrv_7_ts_x64.dll | Out-Null
Copy-S3Object -AccessKey {s3_key} -SecretKey {s3_secret} -BucketName {s3_bucket} -Key Configuration/{name}/{environment}/servers.json -LocalFile C:/ADPasswordReset/config/servers.json | Out-Null 

#Create php fastCgi IIS handler
Add-WebConfiguration "system.webserver/fastcgi" -value @{"FullPath" = "C:\php\php-cgi.exe"}
Add-WebConfiguration "system.webServer/fastCgi/application[@fullPath='C:\php\php-cgi.exe']/environmentVariables" -Value @{"Name" = "PHP_FCGI_MAX_REQUESTS"; Value = 100}
New-WebHandler -Name "PHP" -Path "*.php" -Verb 'GET,POST' -Modules FastCgiModule -scriptProcessor 'C:\PHP\php-cgi.exe' -ResourceType File

#download latest code from github
Invoke-RestMethod -Uri https://api.github.com/repos/Firmstep/FS-ADPasswordReset/zipball/{gitbranch} -Headers @{"Authorization" = "token {github}"} -OutFile C:/TempDownloads/ADPasswordReset.zip
c:\Program` Files\7-Zip\7z.exe x c:\TempDownloads\ADPasswordReset.zip -oc:\TempDownloads\ADPasswordReset | Out-Null
$out = GET-ChildItem c:\TempDownloads\ADPasswordReset\Firmstep-FS-ADPasswordReset*
Move-Item $out\* c:\ADPasswordReset
Set-ItemProperty 'IIS:\Sites\Default Web Site\' -name physicalPath -value c:\ADPasswordReset\PHP

#Create phpinfo file in webroot folder
#New-Item "c:/ADPasswordReset/PHP/info.php" -type File -force -value "<?php phpinfo(); ?>"

#Create Build file in webroot folder
new-item "C:/ADPasswordReset/PHP/build.txt" -type File -force -value "Build: {name} {build}"

$config = @" 
{ 
  "fam_key": "NZEwN7TDaDtNQ/Xnqfepd+9Y3sJN4yUdNkAGgO6qMNE=", 
  "fam_iv": "mdPIckeljQUL7Qnsdro8WA==", 
  "fam_url": "http://firmstepauth-test.appspot.com/famlogin", 
  "fam_cipher": "AES",
  "environment": "{environment}",
  "domain_name": "{domain_name}",
  "domain_netbios_name": "{domain_netbios_name}",
  "domain_ou_name": "{domain_ou_name}",
  "db_host": "localhost", 
  "db_database": "PasswordReset", 
  "db_user": "sa", 
  "db_pass": "$($sqlpass)",
  "group": "{permissions_group}", 
  "gateway_hostname": "{gateway_hostname}"
} 
"@ 
New-Item "c:/ADPasswordReset/config/common.json" -type File -force -value $config 

Copy-S3Object -AccessKey {s3_key} -SecretKey {s3_secret} -BucketName {s3_bucket} -Key Configuration/{name}/{environment}/servers.json -LocalFile C:/ADPasswordReset/config/servers.json | Out-Null

#Download and install SSL certificate
Copy-S3Object -AccessKey {s3_key} -SecretKey {s3_secret} -BucketName fs-deploy -Key Configuration/Certificates/{environment}/certificate.pfx -LocalFile C:\TempDownloads\certificate.pfx
C:\Windows\System32\certutil.exe -f -p {sslcertpassword} -importpfx "C:\TempDownloads\certificate.pfx"
$cert = Get-ChildItem -Path Cert:\LocalMachine\My | Select-Object -First 1
New-WebBinding -Name "Default Web Site" -IP "*" -Port 443 -Protocol https
New-Item -Path IIS:\SslBindings\0.0.0.0!443 -Value $cert

#Build Domain Controller
C:\Windows\system32\schtasks.exe /create /sc ONSTART /tn JoinDomain /tr "powershell.exe C:\ADPasswordReset\DomainSetup.ps1 >> C:\automation.log 2>> C:\automationerr.log" /RU System /RL HIGHEST
C:\Windows\system32\schtasks.exe /create /sc MINUTE /tn PasswordReset /tr "powershell.exe C:\ADPasswordReset\SQLPasswordReset.ps1" /RU System /RL HIGHEST

#prevent IE first-time run screen
New-Item -Path "HKLM:\Software\Policies\Microsoft\Internet Explorer"
New-Item -Path "HKLM:\Software\Policies\Microsoft\Internet Explorer\Main"
New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Internet Explorer\Main" -Name DisableFirstRunCustomize -Value 1 -PropertyType DWORD

{snip_win_monitoring}

# Cleanup
Remove-Item "C:\Users\Default\Desktop\*.*"
Remove-Item "C:\TempDownloads" -Recurse -Force

Stop-Computer

</powershell>
