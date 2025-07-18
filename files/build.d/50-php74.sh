#!/bin/sh
set -e
ARCH=`uname -m`
REMI_URL=http://ftp.riken.jp/Linux/remi/enterprise/9/safe/$ARCH/
mkdir /tmp/root
for i in php php-common php-intl php-pdo php-mysqlnd php-gd php-json php-xml php-mbstring php-fpm php-cli php-process php-smbclient php-pecl-zip php-pecl-apcu php-pecl-redis6 php-pecl-igbinary php-pecl-msgpack; do
        download `get-rpm-download-url $REMI_URL php74-$i` > /tmp/root/$i.rpm
done

mkdir /tmp/sandbox
for i in oniguruma5php gd3php libavif libicu74; do
	download `get-rpm-download-url $REMI_URL $i` > /tmp/sandbox/$i.rpm
done

CENTOS_URL=http://ftp.riken.jp/Linux/centos-stream/9-stream/BaseOS/$ARCH/os/
for i in libxml2 libsmbclient samba-client-libs samba-common-libs libwbclient libicu libtevent libldb; do
	download `get-rpm-download-url $CENTOS_URL $i` > /tmp/sandbox/$i.rpm
done

CENTOS_APPSTREAM_URL=http://ftp.riken.jp/Linux/centos-stream/9-stream/AppStream/$ARCH/os/
for i in libxslt; do
    download `get-rpm-download-url $CENTOS_APPSTREAM_URL $i` > /tmp/sandbox/$i.rpm
done

EPEL_URL=http://ftp.riken.jp/Linux/fedora/epel/9/Everything/$ARCH/
for i in libraqm svt-av1-libs liblzf libimagequant; do
	download `get-rpm-download-url $EPEL_URL $i` > /tmp/sandbox/$i.rpm
done

FEDORA_URL=http://ftp.riken.jp/Linux/fedora/releases/39/Everything/$ARCH/os/
for i in libdav1d; do
    download `get-rpm-download-url $FEDORA_URL $i` > /tmp/sandbox/$i.rpm
done

for i in /tmp/root/*.rpm; do
	echo "Extracting $i into /..."
        rpm2targz -O $i | tar zxf - -C /
done

REMI_ROOT=/opt/remi/php74/root
for i in /tmp/sandbox/*.rpm; do
	echo "Extracting $i into $REMI_ROOT..."
	rpm2targz -O $i | tar zxf - -C $REMI_ROOT
done

echo "Patching ELF binaries..."
# findelf is a utility provided by genpack-progs
findelf $REMI_ROOT | xargs -I {} patchelf --set-rpath "$REMI_ROOT/usr/lib64:$REMI_ROOT/usr/lib64/samba" {}

sed -i 's/^pdo_mysql\.default_socket=.*$/pdo_mysql.default_socket=\/run\/mysqld\/mysqld.sock/' /etc/opt/remi/php74/php.ini
sed -i 's/^mysqli\.default_socket =.*$/mysqli.default_socket = \/run\/mysqld\/mysqld.sock/' /etc/opt/remi/php74/php.ini

#sed -i '/^ExecStart=.*$/a Environment=LD_LIBRARY_PATH=/opt/remi/php74/root/usr/lib64:/opt/remi/php74/root/usr/lib64/samba' /usr/lib/systemd/system/php74-php-fpm.service

chown -R root:apache /var/opt/remi/php74/lib/php/opcache /var/opt/remi/php74/lib/php/session /var/opt/remi/php74/lib/php/wsdlcache

if [ -d /etc/apache2/modules.d ]; then
	ln -s /etc/httpd/conf.d/php74-php.conf /etc/apache2/modules.d/70_remi_php74_php.conf
fi

cat << 'EOS' > /usr/bin/php
#!/bin/bash
REMI_ROOT=/opt/remi/php74/root
exec $REMI_ROOT/usr/bin/php "$@"
EOS
chmod +x /usr/bin/php