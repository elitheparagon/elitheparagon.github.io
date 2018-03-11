#!/usr/bin/env bash

{snip_deb_sysctl}

# General commands
echo "deb [arch=amd64] https://apt-mo.trafficmanager.net/repos/mssql-ubuntu-xenial-release/ xenial main" > /etc/apt/sources.list.d/mssqlpreview.list
apt-key adv --keyserver apt-mo.trafficmanager.net --recv-keys 417A0893

apt update -y
apt install -y apache2 php7.0-cli libapache2-mod-php7.0 php7.0-mysql php7.0-curl php7.0-mbstring php7.0-xml php-pear php7.0-dev
apt install -y awscli unzip
ACCEPT_EULA=Y apt install -y msodbcsql unixodbc-dev-utf16
pecl install pdo_sqlsrv-4.0.6
echo "extension=/usr/lib/php/20151012/pdo_sqlsrv.so" >> /etc/php/7.0/cli/php.ini
echo "extension=/usr/lib/php/20151012/pdo_sqlsrv.so" >> /etc/php/7.0/apache2/php.ini
#apt upgrade -y

{snip_deb_security}

{snip_deb_timezone}

{snip_deb_swap}

# Prepare directories
rm -r /var/www/*

# Download project from GitHub
curl -s -H "Authorization: token {github}" -o /tmp/{name}.tar -L https://api.github.com/repos/Firmstep/FS-Infrastructure/tarball/{gitbranch}
tar xf /tmp/{name}.tar -C /tmp
outfolder=$( ls -1c /tmp | grep Firmstep-FS-Infrastructure- | head -1)
mkdir -p /var/www/{name}
cp -R /tmp/$outfolder/API/* /var/www/{name}/
mkdir -p /var/www/{name}/LIMMonitor
cp -R /tmp/$outfolder/LIMMonitor/* /var/www/{name}/LIMMonitor/
rm -R /tmp/$outfolder
rm /tmp/{name}.tar

# Copy custom files from S3
export AWS_ACCESS_KEY_ID={s3_key}
export AWS_SECRET_ACCESS_KEY={s3_secret}
export AWS_DEFAULT_REGION={s3_region}
aws s3 cp s3://{s3_bucket}/Configuration/{name}/{environment}/common.php /var/www/{name}/config/common.php
aws s3 cp s3://{s3_bucket}/Configuration/{name}/{environment}/common.php /var/www/{name}/LIMMonitor/config/common.php
aws s3 cp s3://{s3_bucket}/Configuration/Certificates/{environment}/certificate.txt /etc/apache2/certificate.txt
aws s3 cp s3://{s3_bucket}/Configuration/Certificates/{environment}/key.txt /etc/apache2/key.txt
aws s3 cp s3://{s3_bucket}/Configuration/Certificates/{environment}/chain.txt /etc/apache2/chain.txt

# Generate VirtualHost File
echo "<VirtualHost *:80>
    RewriteEngine On
    RewriteRule (.*) https://%{SERVER_NAME}$1 [R,L]
</VirtualHost>
<VirtualHost *:443>
    DocumentRoot /var/www/{name}/public
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
    <Directory /var/www/{name}/public>
        Options +Includes -Indexes +FollowSymLinks +MultiViews 
        AllowOverride All
        Require all granted
		RewriteEngine on
		RewriteRule (.*) /index.php [L,QSA]
    </Directory>
	SSLEngine on
    SSLCertificateFile /etc/apache2/certificate.txt
    SSLCertificateKeyFile /etc/apache2/key.txt
    SSLCertificateChainFile /etc/apache2/chain.txt
</VirtualHost>" > /etc/apache2/sites-available/{name}.conf

# Create build file
printf "Build: {name} {build}" > /var/www/{name}/public/build

{snip_deb_opcache}

{snip_deb_monitoring}

{snip_deb_permissions}

# Finalise apache deployment environment
a2dissite 000-default
a2enmod rewrite
a2enmod ssl
a2ensite {name}
rm -f /etc/apache2/sites-available/000-default.conf
rm -f /etc/apache2/sites-available/default-ssl.conf
service apache2 restart

# Setup crontab
echo "*/15 * * * * sudo sh -c 'echo 1 > /proc/sys/vm/drop_caches'
* * * * * php /var/www/{name}/scripts/token_cache.php
0 * * * * php /var/www/{name}/LIMMonitor/lim_monitor.php
0 * * * * php /var/www/{name}/scripts/truncate_componentslog.php hourly
*/10 * * * * php /var/www/{name}/scripts/monitoring/monitoring_truncate.php
* * * * * php /var/www/{name}/scripts/monitoring/monitoring_check.php
* * * * * php /var/www/{name}/scripts/monitoring/slack_message_trigger.php
* * * * * php /var/www/{name}/scripts/monitoring/pingdom_cache_update.php
* * * * * php /var/www/{name}/scripts/monitoring/monitor_server_calculate.php
* * * * * php /var/www/{name}/scripts/monitoring/monitoring_guid_check.php
{cron_components_daily} php /var/www/{name}/scripts/truncate_componentslog.php daily
{cron_log_truncate} php /var/www/{name}/scripts/truncate_cronlog.php
{cron_report_error} php /var/www/{name}/scripts/tracking/reports.php Error
{cron_report_tracking} php /var/www/{name}/scripts/tracking/reports.php Tracking
{cron_statistics} php /var/www/{name}/scripts/tracking/statistics.php
{cron_rrc_cleanup} php /var/www/{name}/scripts/tracking/rrc_cleanup.php
{cron_rrc_statistics} php /var/www/{name}/scripts/tracking/rrc_statistics.php" >> mycron
crontab -u ubuntu mycron
rm mycron

# Setup rc.local (ubuntu on safe reboot)
sed -i -e '$i \nohup sudo -H -u ubuntu bash -c "php /var/www/{name}/scripts/database.php" &\n' /etc/rc.local
sed -i -e '$i \nohup sudo -H -u ubuntu bash -c "php /var/www/{name}/scripts/crontab/database.php" &\n' /etc/rc.local
sed -i -e '$i \nohup sudo -H -u ubuntu bash -c "php /var/www/{name}/scripts/proxy/database.php" &\n' /etc/rc.local
sed -i -e '$i \nohup sudo -H -u ubuntu bash -c "php /var/www/{name}/scripts/limmonitor/database.php" &\n' /etc/rc.local
sed -i -e '$i \nohup sudo -H -u ubuntu bash -c "php /var/www/{name}/scripts/monitoring/database.php" &\n' /etc/rc.local
sed -i -e '$i \nohup sudo -H -u ubuntu bash -c "php /var/www/{name}/scripts/logging/database.php" &\n' /etc/rc.local

# Finally shut down the instance for AMI creation
sudo shutdown -h now
