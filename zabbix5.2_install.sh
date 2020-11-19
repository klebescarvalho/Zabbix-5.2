#!/bin/bash

#- Zabbix 5.2 installation script on Ubuntu Server 18.04 
#- Ubuntu 18.04
#- Zabbix 5.2
#- Author: Kleber Carvalho
#- E-mail: kleb.linux@gmail.com
#- Date: 2020-11-17

#- It is required internet access least at ports 53, 80 and 443.
#- Variables, please add here your password for MySql and zabbix_server.conf
#- NOTE: Default password is zabbix.
#- NOTE: Finds the appropriate timezone and edit at lines 49 and 71

#- Reference
#- Zabbix Website
#- https://www.zabbix.com/download?zabbix=5.2&os_distribution=ubuntu&os_version=18.04_bionic&db=mysql&ws=apache

PASSDB=zabbix

#- MySql Session 
mkdir -p /tmp/zinstall ; cd /tmp/zinstall
apt update
apt-get install mysql-server mysql-client -y

mysql -uroot -e "create database zabbix character set utf8 collate utf8_bin;"
mysql -uroot -e "create user zabbix@localhost identified by '$PASSDB';"
mysql -uroot -e "grant all privileges on zabbix.* to zabbix@localhost;"

#- Zabbix Session
wget https://repo.zabbix.com/zabbix/5.2/ubuntu/pool/main/z/zabbix-release/zabbix-release_5.2-1+ubuntu18.04_all.deb
dpkg -i zabbix-release_5.2-1+ubuntu18.04_all.deb

apt update
apt install build-essential module-assistant -y
apt install open-vm-tools -y
apt install locales -y
locale-gen pt_PT.UTF-8 
m-a prepare -y
update-locale LANG=pt_PT.UTF-8

apt install zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-agent -y
apt install php-mysql php-gd php-xml-util php-bcmath php-net-socket php-gettext -y
apt install nmap -y 
apt install snmp -y  
apt install snmp-mibs-downloader -y
apt install jq -y

#- MySql population 
zcat /usr/share/doc/zabbix-server-mysql*/create.sql.gz | mysql -uroot zabbix

#- Configuration Session
#- Apache2
#- Finds here the appropriate timezone 
#- https://www.php.net/manual/en/timezones.php 
sed -i 's/# php_value date.timezone Europe\/Riga/php_value date.timezone Africa\/Luanda/g' /etc/apache2/conf-enabled/zabbix.conf

#- Zabbix Server
cp -rfp /etc/zabbix/zabbix_server.conf /etc/zabbix/zabbix_server.conf-orig
sed -i "s/# DBPassword=/DBPassword=$PASSDB/g" /etc/zabbix/zabbix_server.conf
sed -i 's/# CacheSize=8M/CacheSize=1024M/g' /etc/zabbix/zabbix_server.conf 

#- Zabbix Agent
cp -rfp /etc/zabbix/zabbix_agentd.conf /etc/zabbix/zabbix_agentd.conf-orig
HOSTNAME=`hostname`
sed -i "s/Hostname=Zabbix server/Hostname=$HOSTNAME/g" /etc/zabbix/zabbix_agentd.conf

#- PHP
PHPINI=`find / -iname php.ini | grep apache2`
cp -rfp $PHPINI $PHPINI-orig

sed -i "s/max_execution_time = 30/max_execution_time = 300/g" $PHPINI
sed -i "s/memory_limit = 128M/memory_limit = 256M/g" $PHPINI
sed -i "s/post_max_size = 8M/post_max_size = 32M/g" $PHPINI
sed -i "s/max_input_time = 60/max_input_time = 300/g" $PHPINI
#- Finds here the appropriate timezone 
#- https://www.php.net/manual/en/timezones.php 
sed -i "s/\;date.timezone =/date.timezone = Africa\/Luanda/g" $PHPINI

#- Restart and enable zabbix and apache services.
systemctl restart zabbix-server zabbix-agent apache2
systemctl enable zabbix-server zabbix-agent apache2

#- Services test
clear
sleep 3 ; echo -n "Wait please"; echo -n .; sleep 3; echo -n . ; sleep 3 ; echo -n . ; echo "" ; sleep 3
echo "" > /tmp/.zabbix_install
echo " ================== Installation Report ================== " >> /tmp/.zabbix_install
echo "|    SERVICES NAME              STATUS                    |" >> /tmp/.zabbix_install
echo " ========================================================= " >> /tmp/.zabbix_install

ZABBIXSERVER=`service zabbix-server status | grep running | awk '{ print $1 }' | cut -d : -f1`
if [ "$ZABBIXSERVER" == "Active" ]; then echo "  Zabbix Server        ||   OK           " >> /tmp/.zabbix_install ; else echo "Zabbix Server is not running"; fi

ZABBIXAGENT=`service zabbix-agent status | grep running | awk '{ print $1 }' | cut -d : -f1`
if [ "$ZABBIXAGENT" == "Active" ]; then echo "  Zabbix Agent         ||   OK           " >> /tmp/.zabbix_install ; else echo "Zabbix Agent is not running"; fi

APACHE2=`service apache2 status | grep running | awk '{ print $1 }' | cut -d : -f1`
if [ "$APACHE2" == "Active" ]; then echo "  Apache2              ||   OK           " >> /tmp/.zabbix_install ; else echo "Apache services is not running"; fi

MYSQL=`service mysql status | grep running | awk '{ print $1 }' | cut -d : -f1`
if [ "$MYSQL" == "Active" ]; then echo "  MySQL                ||   OK           " >> /tmp/.zabbix_install ; else echo "MySql services is not running"; fi

echo "=========================================================" >> /tmp/.zabbix_install
IPADDRESS=`ip addr | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{ print $2 }' | cut -d / -f1 | head -n 1`
echo "" >> /tmp/.zabbix_install
echo "http://$IPADDRESS/zabbix           <- Open your browser and type this." >> /tmp/.zabbix_install
echo "User: Admin  ,   Password: zabbix" >> /tmp/.zabbix_install
echo "" >> /tmp/.zabbix_install
echo "" >> /tmp/.zabbix_install

#- Remove 
cat /tmp/.zabbix_install
cd /tmp
rm -rf /tmp/zinstall
rm -rf /tmp/.zabbix_install

