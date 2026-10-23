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
# 置かれなくなった(10.16.3 で止まっている)ので GitHub の release から取得する。
#
# ownCloud は 10.x と 11.x を並行保守しており、GitHub の releases/latest は
# 「公開日の新しい」リリースを返すため v11.0.1(09-25)より後に出た v10.16.6(10-06)が
# latest になってしまう。latest 経由(get-github-download-url)では PHP 8.3 必須の
# 11.x を確実に取れないので、releases 一覧から version 順で 11.x の最大を選ぶ。
# tarball は owncloud-<version>.tar.bz2(-qa 版や owncloud-complete-* バンドルではない)。
OC_TAG=`download https://api.github.com/repos/owncloud/core/releases?per_page=100 \
	| jq -r '.[].tag_name' | grep -E '^v11\.[0-9]+\.[0-9]+$' | sort -V | tail -1`
test -n "$OC_TAG" || { echo "no ownCloud 11.x release found" >&2; exit 1; }
echo "ownCloud ${OC_TAG#v}"
download https://github.com/owncloud/core/releases/download/$OC_TAG/owncloud-${OC_TAG#v}.tar.bz2 \
	| tar jxf - --strip-components=1 -C /var/www/localhost/htdocs

mkdir /var/lib/owncloud
chown -R apache.apache /var/www/localhost /var/lib/owncloud

mkdir -p /.genpack
php -r 'include "/var/www/localhost/htdocs/version.php";echo $OC_VersionString;' > /.genpack/owncloud-version
