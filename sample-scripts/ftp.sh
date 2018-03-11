#!/usr/bin/env bash

{snip_deb_sysctl}

# General commands
export DEBIAN_FRONTEND=noninteractive
apt update -y
apt install -y apache2 libapache2-mod-php7.0
apt install -y cron awscli php7.0-cli php7.0-mysql vsftpd libpam-mysql iptables-persistent
#apt upgrade -y

{snip_deb_security}

{snip_deb_timezone}

{snip_deb_swap}

# libpam-mysql fix
wget -P /tmp http://www.dinofly.com/files/linux/libpam-mysql_0.7~RC1-4ubuntu3_amd64.deb
dpkg -i /tmp/libpam-mysql_0.7~RC1-4ubuntu3_amd64.deb

# Copy custom files from S3
export AWS_ACCESS_KEY_ID={s3_key}
export AWS_SECRET_ACCESS_KEY={s3_secret}
export AWS_DEFAULT_REGION={s3_region}
aws s3 cp s3://{s3_bucket}/Configuration/{name}/{environment}/common.php /home/ubuntu/bin/{name}/config/common.php

# Download project from GitHub
curl -s -H "Authorization: token {github}" -o /tmp/FS-Solutions.tar -L https://api.github.com/repos/Firmstep/FS-Solutions/tarball/{gitbranch}
tar xf /tmp/FS-Solutions.tar -C /tmp
outfolder=$( ls -1c /tmp | grep Firmstep-FS-Solutions- | head -1)
cp -R /tmp/$outfolder/{name} /home/ubuntu/bin
rm -R /tmp/$outfolder
rm /tmp/FS-Solutions.tar

# Add VSFTPD user
useradd --home /home/vsftpd --gid nogroup -m --shell /bin/false vsftpd

# VSFTPD config file
cp /etc/vsftpd.conf /etc/vsftpd.conf_orig
cat /dev/null > /etc/vsftpd.conf
echo "listen=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
nopriv_user=vsftpd
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/vsftpd.pem
guest_enable=YES
guest_username=vsftpd
local_root=/home/vsftpd/\$USER
user_sub_token=\$USER
virtual_use_local_privs=YES
user_config_dir=/etc/vsftpd_user_conf
pasv_enable=Yes
pasv_min_port={ftp_min_port}
pasv_max_port={ftp_max_port}
pasv_address={ftp_address}
pasv_addr_resolve=YES" > /etc/vsftpd.conf
mkdir /etc/vsftpd_user_conf

iptables -I INPUT -p tcp --destination-port {ftp_min_port}:{ftp_max_port} -j ACCEPT
ufw allow {ftp_min_port}:{ftp_max_port}/tcp

sudo netfilter-persistent save

# PAM config files for VSFTPD
cp /etc/pam.d/vsftpd /etc/pam.d/vsftpd_orig
cat /dev/null > /etc/pam.d/vsftpd
echo "auth required pam_mysql.so user={pam_mysql_user} passwd={pam_mysql_pass} host={pam_mysql} db={pam_mysql_db} table={pam_mysql_table} usercolumn=ftp_user passwdcolumn=ftp_pass crypt=3
account required pam_mysql.so user={pam_mysql_user} passwd={pam_mysql_pass} host={pam_mysql} db={pam_mysql_db} table={pam_mysql_table} usercolumn=ftp_user passwdcolumn=ftp_pass crypt=3" > /etc/pam.d/vsftpd

# Restart Vsftpd service
/etc/init.d/vsftpd restart

# Create build file
printf "Build: {name} {build}" > /var/www/html/build
rm /var/www/html/index.html
a2dismod autoindex -f

{snip_deb_monitoring}

# Setup permissions
chown -R ubuntu:ubuntu /home/ubuntu/bin
chmod -R 770 /home/ubuntu/bin

# Make data directory for mountpoint
mkdir /data

# Setup crontab
echo "*/15 * * * * sudo sh -c 'echo 1 > /proc/sys/vm/drop_caches'
{migrate_cronkey} sudo php /home/ubuntu/bin/{name}/script/migrate.php llpg
{migrate_cronkey} sudo php /home/ubuntu/bin/{name}/script/migrate.php asset
{migrate_cronkey} sudo php /home/ubuntu/bin/{name}/script/migrate.php mbcollection
* * * * * sudo php /home/ubuntu/bin/{name}/script/checkUser.php" >> mycron
crontab -u ubuntu mycron
rm mycron

# Setup rc.local (ubuntu on safe reboot)
sed -i -e '$i \nohup sudo mount /dev/xvdf /data &\n' /etc/rc.local
sed -i -e '$i \nohup netfilter-persistent reload &\n' /etc/rc.local
sed -i -e '$i \nohup bash -c "sleep 180 && sudo /etc/init.d/vsftpd restart" &\n' /etc/rc.local

# Finally shut down the instance for AMI creation
sudo shutdown -h now
