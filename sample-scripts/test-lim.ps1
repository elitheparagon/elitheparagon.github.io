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

if ("{environment}" -eq "test") {
    {snip_win_domainjoin}
}

if ($errors) {
    Send-MailMessage -From "{name}@firmstep.com" -To "auckland-team@firmstep.com" -Subject "{name} Automation Error [{environment}]" -SmtpServer "smtp.firmstep.com" -Body "$errors"
}

# Run shared LIM setup script
if (-Not (Test-Path "C:\Firmstep")) { New-Item -ItemType directory -Path C:\Firmstep | Out-Null }
$r = Invoke-WebRequest -URI https://api.github.com/repos/Firmstep/FS-Automation/contents/shared/lim-common.ps1 -Headers @{"Authorization"="token {github}"}
$c = $r.Content | ConvertFrom-Json
$decoded = [System.Convert]::FromBase64String($c.content)
[IO.File]::WriteAllBytes("C:\Firmstep\lim-common.ps1",$decoded)
Invoke-Expression "C:\Firmstep\lim-common.ps1"
Remove-Item "C:\Firmstep\lim-common.ps1"

# Install environment-specific LIM config files
Copy-S3Object -AccessKey {s3_key} -SecretKey {s3_secret} -Region {s3_region} -BucketName {s3_bucket} -Key Configuration/{name}/{environment}/log4net.config -LocalFile C:/LIM/log4net.config | Out-Null
Copy-S3Object -AccessKey {s3_key} -SecretKey {s3_secret} -Region {s3_region} -BucketName {s3_bucket} -Key Configuration/{name}/{environment}/lim.config -LocalFile C:/LIM/lim.config | Out-Null

# Download folder permissions script and set it to run on next reboot
# (can't run it during automation as the D: drive won't be attached)
$r = Invoke-WebRequest -URI https://api.github.com/repos/Firmstep/FS-Automation/contents/shared/lim-folder-permissions.ps1 -Headers @{"Authorization"="token {github}"}
$c = $r.Content | ConvertFrom-Json
$decoded = [System.Convert]::FromBase64String($c.content)
[IO.File]::WriteAllBytes("C:\Firmstep\lim-folder-permissions.ps1",$decoded)
C:\Windows\system32\schtasks.exe /create /sc ONSTART /tn LIMFolderPermissions /tr "powershell.exe C:\Firmstep\lim-folder-permissions.ps1 -NoLogo -NonInteractive -WindowStyle Hidden" /RU System

# Download FAM setup script and set it to run on next reboot
# (Can't run it during automation as the D: drive won't be attached)
$r = Invoke-WebRequest -URI https://api.github.com/repos/Firmstep/FS-Automation/contents/shared/DebugFAMSetup.ps1 -Headers @{"Authorization"="token {github}"}
$c = $r.Content | ConvertFrom-Json
$decoded = [System.Convert]::FromBase64String($c.content)
[IO.File]::WriteAllBytes("C:\Firmstep\DebugFAMSetup.ps1",$decoded)
C:\Windows\system32\schtasks.exe /create /sc ONSTART /tn DebugFAMSetup /tr "powershell.exe C:\Firmstep\DebugFAMSetup.ps1 -NoLogo -NonInteractive -WindowStyle Hidden" /RU System

# Install debug FAM
Add-WindowsFeature -Name Web-Asp
Import-Module WebAdministration
if (-Not (Test-Path "C:\FAM")) { New-Item -ItemType directory -Path C:\FAM | Out-Null }
Copy-S3Object -AccessKey {s3_key} -SecretKey {s3_secret} -Region {s3_region} -BucketName {s3_bucket} -Key FAMASP.zip -LocalFile C:/TempDownloads/FAMASP.zip | Out-Null
c:\Program` Files\7-Zip\7z.exe x c:\TempDownloads\FAMASP.zip -o"C:\FAM"
c:\Windows\SysWOW64\regsvr32.exe C:\FAM\VBCorLib.dll
c:\Windows\SysWOW64\regsvr32.exe C:\FAM\FAMASP.dll
New-WebAppPool -Name "FAM"
Set-ItemProperty -Path IIS:\AppPools\FAM -Name managedRuntimeVersion -Value ''
Set-ItemProperty -Path IIS:\AppPools\FAM -Name enable32BitAppOnWin64 -Value "true"

# Install FillTask Agent
(New-Object System.Net.WebClient).DownloadFile("https://fs-deploy.s3.amazonaws.com/FillTaskAgent.zip", "C:\TempDownloads\FillTaskAgent.zip")
c:\Program` Files\7-Zip\7z.exe x c:\TempDownloads\FillTaskAgent.zip -oc:\FillTaskAgent | Out-Null

# Copy FillTask agent config files and scripts
Copy-S3Object -AccessKey {s3_key} -SecretKey {s3_secret} -Region {s3_region} -BucketName {s3_bucket} -Key Configuration/{name}/{environment}/agent.config -LocalFile C:/FillTaskAgent/agent.config | Out-Null

# FillTaskCleanup script
$r = Invoke-WebRequest -URI https://api.github.com/repos/Firmstep/FS-Automation/contents/shared/FillTaskCleanup-{environment}.ps1 -Headers @{"Authorization"="token {github}"}
$c = $r.Content | ConvertFrom-Json
$decoded = [System.Convert]::FromBase64String($c.content)
[IO.File]::WriteAllBytes('C:\FillTaskAgent\FillTaskCleanup.ps1',$decoded)

# FillTaskCleanup script
$r = Invoke-WebRequest -URI https://api.github.com/repos/Firmstep/FS-Automation/contents/shared/FillTaskTrigger-{environment}.ps1 -Headers @{"Authorization"="token {github}"}
$c = $r.Content | ConvertFrom-Json
$decoded = [System.Convert]::FromBase64String($c.content)
[IO.File]::WriteAllBytes('C:\FillTaskAgent\FillTaskTrigger.ps1',$decoded)

# Set tasks for FillTask Agent
C:\Windows\system32\schtasks.exe /create /sc daily /st 00:00 /ri 10 /du 24:00 /tn FillTaskAgent /tr 'C:\FillTaskAgent\ConsoleApp\ConsoleApp.exe' /RU System /RL HIGHEST | Out-Null
C:\Windows\system32\schtasks.exe /create /sc daily /st 22:25 /tn FillTaskCleanup /tr 'powershell.exe C:\FillTaskAgent\FillTaskCleanup.ps1' /RU System /RL HIGHEST | Out-Null
C:\Windows\system32\schtasks.exe /create /sc daily /st 00:05 /ri 60 /du 24:00 /tn FillTaskTrigger /tr 'powershell.exe C:\FillTaskAgent\FillTaskTrigger.ps1' /RU System /RL HIGHEST | Out-Null

# Create Build file in webroot folder
New-Item "C:/inetpub/wwwroot/build.txt" -type File -force -value "Build: {name} {build}"

# Cleanup
Remove-Item "C:\Users\Default\Desktop\*.*"
Remove-Item "C:\TempDownloads" -Recurse -Force

Stop-Computer

</powershell>
