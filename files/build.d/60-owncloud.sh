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
# ownCloud は 10.x と 11.x を並行保守しており、GitHub の releases/latest は「公開日の
# 新しい」リリースを返すため v11.0.1(09-25)より後に出た v10.16.6(10-06)が latest に
# なってしまう。latest 経由では PHP 8.3 必須の 11.x を確実に取れないので、core は
# semver で最大 11.x を選び、そのリリースに紐づくアセットを展開する。
#
# variant で同梱範囲を選ぶ (VARIANT 環境変数):
#   (既定)     Server 版   owncloud-<ver>.tar.bz2            = core 結合アプリのみ
#   complete   bundled 版  owncloud-complete-<date>.tar.bz2  = アプリ一式(多くは無効同梱)
# 両者ともトップレベルは単一 owncloud/ なので --strip-components=1 で共通。
case "$VARIANT" in
	complete) ASSET_RE='^owncloud-complete-[0-9]+\.tar\.bz2$'; KIND="complete bundle" ;;
	*)        ASSET_RE='^owncloud-[0-9.]+\.tar\.bz2$';         KIND="server" ;;
esac
SELECTION=$(download https://api.github.com/repos/owncloud/core/releases?per_page=100 \
	| jq -r --arg re "$ASSET_RE" '[ .[]
		| select(.prerelease == false)
		| select(.tag_name | test("^v11\\.[0-9]+\\.[0-9]+$"))
		| . as $r
		| (($r.assets[]? | select(.name | test($re)) | .browser_download_url) // null) as $a
		| select($a != null)
		| {v:($r.tag_name | ltrimstr("v") | split(".") | map(tonumber)), tag:$r.tag_name, url:$a}
	] | sort_by(.v) | last | "\(.tag) \(.url)"')
test -n "$SELECTION" || { echo "no ownCloud 11.x ${KIND} asset found" >&2; exit 1; }
set -- $SELECTION
OC_TAG=$1; OC_URL=$2
echo "ownCloud ${OC_TAG#v} (${KIND})"
download "$OC_URL" | tar jxf - --strip-components=1 -C /var/www/localhost/htdocs

mkdir /var/lib/owncloud
chown -R apache.apache /var/www/localhost /var/lib/owncloud

mkdir -p /.genpack
php -r 'include "/var/www/localhost/htdocs/version.php";echo $OC_VersionString;' > /.genpack/owncloud-version
