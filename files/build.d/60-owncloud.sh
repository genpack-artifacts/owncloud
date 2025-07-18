#!/bin/sh
set -e

cat << 'EOS' > /tmp/sql
create database `owncloud`;
create user `owncloud`@localhost;
grant all privileges on `owncloud`.* to `owncloud`@localhost;
EOS

with-mysql --mysql-plugin=auth_socket.so 'mysql -u root < /tmp/sql'

# setup PHP
if [ ! -d /opt/remi/php74 ]; then
	echo "ownCloud needs PHP 7.4!"
	exit1 1
fi

#else
systemctl enable php74-php-fpm
PHP_INI=/etc/opt/remi/php74/php.ini

sed -i 's/^upload_max_filesize.\+$/upload_max_filesize = 512M/' $PHP_INI
sed -i 's/^post_max_size.\+$/post_max_size = 768M/' $PHP_INI
sed -i 's/^memory_limit.\+$/memory_limit=512M/' $PHP_INI
sed -i 's/^;mbstring.func_overload.\+$/mbstring.func_overload=0/' $PHP_INI
sed -i 's/^;always_populate_raw_post_data.\+$/always_populate_raw_post_data=-1/' $PHP_INI
sed -i 's/^;default_charset.\+$/default_charset="UTF-8"/' $PHP_INI


echo "Extrtacting ownCloud..."
download https://download.owncloud.com/server/stable/owncloud-latest.tar.bz2 | tar jxf - --strip-components=1 -C /var/www/localhost/htdocs

mkdir /var/lib/owncloud
chown -R apache.apache /var/www/localhost /var/lib/owncloud

mkdir -p /.genpack
php -r 'include "/var/www/localhost/htdocs/version.php";echo $OC_VersionString;' > /.genpack/owncloud-version
