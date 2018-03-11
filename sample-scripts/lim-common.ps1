if (-Not (Test-Path "C:\TempDownloads")) { New-Item -ItemType directory -Path C:\TempDownloads | Out-Null }

Import-Module ServerManager
Add-WindowsFeature -Name Web-Common-Http,Web-Asp-Net,Web-Net-Ext,Web-ISAPI-Ext,Web-Request-Monitor,Web-Basic-Auth,Web-Windows-Auth,Web-Performance,Web-Mgmt-Console,WAS -IncludeAllSubFeature | Out-Null
C:\Windows\Microsoft.NET\Framework\v4.0.30319\aspnet_regiis.exe -i | Out-Null

write-host "Downloading and installing 7zip"
(New-Object System.Net.WebClient).DownloadFile("http://www.7-zip.org/a/7z1514-x64.msi", "C:\TempDownloads\7zip.msi")
msiexec /package "C:\TempDownloads\7zip.msi" /quiet /passive /qn /norestart | Out-Null

write-host "Downloading and installing Notepad++"
(New-Object System.Net.WebClient).DownloadFile("https://notepad-plus-plus.org/repository/7.x/7.2/npp.7.2.Installer.exe", "C:\TempDownloads\npp.exe")
C:\TempDownloads\npp.exe /Q /S | Out-Null

write-host "Downloading and installing Chrome"
(New-Object System.Net.WebClient).DownloadFile("http://dl.google.com/chrome/install/375.126/chrome_installer.exe", "C:\TempDownloads\chrome.exe")
C:\TempDownloads\chrome.exe /silent /install | Out-Null

write-host "Downloading and installing AWS CLI Tools"
(New-Object System.Net.WebClient).DownloadFile("https://s3.amazonaws.com/aws-cli/AWSCLI64.msi", "C:\TempDownloads\AWSCLI64.msi")
msiexec /package "C:\TempDownloads\AWSCLI64.msi" /quiet /passive /qn /norestart | Out-Null

write-host "Downloading and installing HeidiSQL"
(New-Object System.Net.WebClient).DownloadFile("http://www.heidisql.com/installers/HeidiSQL_9.3.0.4984_Setup.exe", "C:\TempDownloads\heidi.exe")
C:\TempDownloads\heidi.exe /silent /install | Out-Null

write-host "Downloading and installing SSMS"
(New-Object System.Net.WebClient).DownloadFile("http://download.microsoft.com/download/E/4/6/E46671CC-30AA-448F-9A65-0A59A073A3B4/SSMS-Setup-ENU.exe", "C:\TempDownloads\ssms.exe")
C:\TempDownloads\ssms.exe /silent /install | Out-Null

write-host "Downloading and installing MySQL ODBC Driver"
(New-Object System.Net.WebClient).DownloadFile("https://downloads.mysql.com/archives/get/file/mysql-connector-odbc-5.3.4-winx64.msi", "C:\TempDownloads\mysql.msi")
msiexec /package "C:\TempDownloads\mysql.msi" /passive | Out-Null

write-host "Downloading and installing latest LIM"
(New-Object System.Net.WebClient).DownloadFile("https://fs-deploy.s3.amazonaws.com/LIM.zip", "C:\TempDownloads\LIM.zip")
c:\Program` Files\7-Zip\7z.exe x c:\TempDownloads\LIM.zip -oc:\LIM | Out-Null

write-host "Downloading and installing NTFS powershell module"
(New-Object System.Net.WebClient).DownloadFile("https://gallery.technet.microsoft.com/scriptcenter/1abd77a5-9c0b-4a2b-acef-90dbb2b84e85/file/107400/19/NTFSSecurity.zip", "C:/TempDownloads/ntfs.zip")
if (-Not (Test-Path "c:\Windows\System32\WindowsPowerShell\v1.0\Modules\NTFSSecurity")) { New-Item -ItemType directory -Path c:\Windows\System32\WindowsPowerShell\v1.0\Modules\NTFSSecurity | Out-Null }
c:\Program` Files\7-Zip\7z.exe x c:\TempDownloads\ntfs.zip -oc:\Windows\System32\WindowsPowerShell\v1.0\Modules\NTFSSecurity | Out-Null

Import-Module WebAdministration
New-Item "IIS:\Sites\Default Web Site\LIM" -physicalPath "C:\LIM" -type Application | Out-Null

Remove-Item "C:\TempDownloads" -Recurse -Force

#remove unnecessary IIS bindings
Remove-ItemProperty "IIS:\Sites\Default Web Site" -Name Bindings -AtElement @{protocol="net.tcp"}
Remove-ItemProperty "IIS:\Sites\Default Web Site" -Name Bindings -AtElement @{protocol="net.pipe"}
Remove-ItemProperty "IIS:\Sites\Default Web Site" -Name Bindings -AtElement @{protocol="net.msmq"}
Remove-ItemProperty "IIS:\Sites\Default Web Site" -Name Bindings -AtElement @{protocol="msmq.formatname"}

#prevent IE first-time run screen
New-Item -Path "HKLM:\Software\Policies\Microsoft\Internet Explorer"
New-Item -Path "HKLM:\Software\Policies\Microsoft\Internet Explorer\Main"
New-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Internet Explorer\Main" -Name DisableFirstRunCustomize -Value 1 -PropertyType DWORD