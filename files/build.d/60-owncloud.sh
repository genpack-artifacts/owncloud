#!/bin/sh
set -e

cat << 'EOS' > /tmp/sql
create database `owncloud`;
create user `owncloud`@localhost;
grant all privileges on `owncloud`.* to `owncloud`@localhost;
EOS

with-mysql --mysql-plugin=auth_socket.so 'mysql -u root < /tmp/sql'

# ownCloud 向けの php.ini 調整(fpm/cli 双方)。PHP 本体のセットアップは 50-php.sh 参照。
PHP_INI=/etc/php/*/php.ini

sed -i 's/^upload_max_filesize.\+$/upload_max_filesize = 512M/' $PHP_INI
sed -i 's/^post_max_size.\+$/post_max_size = 768M/' $PHP_INI
sed -i 's/^memory_limit.\+$/memory_limit=512M/' $PHP_INI
sed -i 's/^;\?default_charset.\+$/default_charset="UTF-8"/' $PHP_INI

echo "Extracting ownCloud..."
# ownCloud 11 以降 https://download.owncloud.com/server/stable/ に tarball が
# 置かれなくなった(10.16.3 で止まっている)ので GitHub の release アセットから取得する。
# -qa 版と owncloud-complete-* バンドルは正規表現で除外している。
download `get-github-download-url owncloud core 'owncloud-[0-9.]+\.tar\.bz2$'` | tar jxf - --strip-components=1 -C /var/www/localhost/htdocs

mkdir /var/lib/owncloud
chown -R apache.apache /var/www/localhost /var/lib/owncloud

mkdir -p /.genpack
php -r 'include "/var/www/localhost/htdocs/version.php";echo $OC_VersionString;' > /.genpack/owncloud-version
