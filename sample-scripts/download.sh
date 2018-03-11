#!/usr/bin/env bash

{snip_deb_sysctl}

# General commands
apt update -y
apt install -y apache2 php7.0-cli libapache2-mod-php7.0 php7.0-mysql php7.0-curl php7.0-mbstring php7.0-xml
apt install -y awscli unzip
#apt upgrade -y

{snip_deb_security}

{snip_deb_timezone}

{snip_deb_swap}

# Prepare directories
rm -r /var/www/*

# Download code from GitHub
curl -s -H "Authorization: token {github}" -o /tmp/{name}.tar -L https://api.github.com/repos/Firmstep/FS-Infrastructure/tarball/{gitbranch}
tar xf /tmp/{name}.tar -C /tmp
outfolder=$( ls -1c /tmp | grep Firmstep-FS-Infrastructure- | head -1)
mkdir -p /var/www/{name}
cp -R /tmp/$outfolder/{name}/* /var/www/{name}/
rm -R /tmp/$outfolder
rm /tmp/{name}.tar

# Copy any required custom files
export AWS_ACCESS_KEY_ID={s3_key}
export AWS_SECRET_ACCESS_KEY={s3_secret}
export AWS_DEFAULT_REGION={s3_region}
aws s3 cp s3://{s3_bucket}/Configuration/{name}/{environment}/common.php /var/www/{name}/config/common.php
aws s3 cp s3://{s3_bucket}/Configuration/Certificates/{environment}/certificate.txt /etc/apache2/certificate.txt
aws s3 cp s3://{s3_bucket}/Configuration/Certificates/{environment}/key.txt /etc/apache2/key.txt
aws s3 cp s3://{s3_bucket}/Configuration/Certificates/{environment}/chain.txt /etc/apache2/chain.txt

# Install the project dependencies
sudo -H -u ubuntu bash -c 'sudo composer install --working-dir=/var/www/{name}'

# VirtualHost tracking.conf
echo "<VirtualHost *:80>
    RewriteEngine On
    RewriteRule (.*) https://%{SERVER_NAME}$1 [R,L]
</VirtualHost>
<VirtualHost *:443>
    DocumentRoot /var/www/{name}/public
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
    <Directory /var/www/{name}/public>
        Options +Includes -Indexes +FollowSymLinks
        AllowOverride All
        Require all granted
		RewriteEngine on
        RewriteCond %{REQUEST_FILENAME} -f
        RewriteRule ^ - [L]
        RewriteCond %{REQUEST_URI} api
        RewriteRule ^api/(.*)$ api/index.php/\$1 [L]
        RewriteRule ^ index.html [L]
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
a2ensite {name}
a2enmod rewrite
a2enmod ssl
rm -f /etc/apache2/sites-available/000-default.conf
rm -f /etc/apache2/sites-available/default-ssl.conf
service apache2 restart

{snip_deb_dropcache}

# Finally shut down the instance for AMI creation
sudo shutdown -h now
