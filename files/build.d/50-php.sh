#!/bin/sh
set -e

# ownCloud 11 は PHP 8.3〜8.5 を要求する(lib/base.php の PHP_VERSION_ID チェック)ため、
# Remi の PHP 7.4 RPM 展開をやめて Gentoo の dev-lang/php を使う。
#
# mod_php ではなく php-fpm を proxy_fcgi 経由で叩く構成(70_php_fpm.conf)。
# 旧構成(Remi の php-fpm + proxy_fcgi)と同形なので apache 側の変更が最小で済み、
# PHP が apache とは別プロセスになるので MPM の選択と PHP の ZTS 要否が独立する
# (ZTS 版が Portage に無い pecl 拡張 apcu/redis/smbclient をそのまま使える)。

# pecl install が phpize 経由で autoconf を呼ぶ
require-installed dev-build/autoconf

PHP_FPM_SLOT=`eselect php show fpm`	# 例: php8.3
PHP_FPM_DIR=/etc/php/fpm-$PHP_FPM_SLOT
PHP_CLI_DIR=/etc/php/cli-`eselect php show cli`

# SMB 外部ストレージ用の smbclient 拡張は Portage に無いので pecl から入れる
download https://pecl.php.net/get/smbclient > /tmp/smbclient.tgz
pecl install /tmp/smbclient.tgz
for i in $PHP_FPM_DIR $PHP_CLI_DIR; do
	echo "extension=smbclient.so" > $i/ext/smbclient.ini
	ln -s ../ext/smbclient.ini $i/ext-active/smbclient.ini
done

# デフォルトのプールは nobody:nobody / 127.0.0.1:9000 なので apache 用の
# unix socket に差し替える(/run/php-fpm は eselect-php の tmpfiles が作る)
cat << 'EOS' > $PHP_FPM_DIR/fpm.d/www.conf
[www]
user = apache
group = apache

listen = /run/php-fpm/www.sock
listen.owner = apache
listen.group = apache
listen.mode = 0660

pm = dynamic
pm.max_children = 32
pm.start_servers = 4
pm.min_spare_servers = 2
pm.max_spare_servers = 8
pm.max_requests = 500

php_admin_value[error_log] = /var/log/php-fpm-www.log
php_admin_flag[log_errors] = on
EOS

sed -i 's/^;\?pdo_mysql\.default_socket\s*=.*$/pdo_mysql.default_socket=\/run\/mysqld\/mysqld.sock/' $PHP_FPM_DIR/php.ini $PHP_CLI_DIR/php.ini
sed -i 's/^;\?mysqli\.default_socket\s*=.*$/mysqli.default_socket=\/run\/mysqld\/mysqld.sock/' $PHP_FPM_DIR/php.ini $PHP_CLI_DIR/php.ini

systemctl enable php-fpm@${PHP_FPM_SLOT#php}
