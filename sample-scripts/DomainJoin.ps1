param ($username, $password, $ip1, $ip2, $domainou, $domainname)

function PostSlackMessage
{
	param([string]$message)
	$json = @{"channel"="auckland-bot"; "username"="DomainJoin"; "text"=$message; "icon_emoji"=":computer:"} | ConvertTo-Json
	Invoke-WebRequest -Method POST -Uri https://hooks.slack.com/services/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 -Body $json
}

if ($domainou -is [System.Array])
{
	$domainou = $domainou -Join ","
}

$instanceID = Invoke-RestMethod http://169.254.169.254/latest/meta-data/instance-id -TimeoutSec 10
#keep retrying until network comes up
while ($instanceID.Length -eq 0)
{
	Write-Host Retrying
	Start-Sleep -s 60
	$instanceID = Invoke-RestMethod http://169.254.169.254/latest/meta-data/instance-id -TimeoutSec 10
}

$newname = $instanceID
$computerName = $env:ComputerName

#shorten to 15 chars if needed
if ($newname.Length -gt 15)
{
	$oldname = $newname
	$newname = $newname.substring(0,15)
	#PostSlackMessage "Truncating $oldname to $newname"
}

#check that DNS resolution is setup correctly
$searchlist = (Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Parameters -Name SearchList).SearchList
if ($searchlist.IndexOf($domainname) -eq -1)
{
	$searchlist = "$searchlist,$domainname"
	Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\services\Tcpip\Parameters -Name SearchList -Value $searchlist
}

#check if name is correct and if not rename
if ($computerName -ne $newname) {
	Rename-Computer -NewName $newname -ErrorVariable $err -Force
	if ($err) {
		PostSlackMessage "DomainJoin rename $instanceID failed with error $err"
	}
	else
	{
		PostSlackMessage "Renamed $instanceID as $newname, was $computerName"
	}
	Restart-Computer -Force
	Exit
}

#check if domain joined
if ((gwmi win32_computersystem).partofdomain -eq $false) {

	#set DNS servers first
	(gwmi win32_networkadapterconfiguration -Filter "index=7").SetDNSServerSearchOrder(@($ip1,$ip2))
	
	#get domain join credentials
	$credentials = New-Object System.Management.Automation.PSCredential($username, (ConvertTo-SecureString $password -AsPlainText -Force))
	
	#join to domain
	Add-Computer -DomainName $domainname -OUPath $domainou -Credential $credentials -ErrorVariable $err -Force
	if ($err) {
		PostSlackMessage "DomainJoin for instance $instanceID failed with error $err"
	}
	else
	{
		PostSlackMessage "Joined $instanceID to $domainname domain as $newname"
	}
	Restart-Computer -Force
	Exit
}

PostSlackMessage "Instance $instanceID is now ready"