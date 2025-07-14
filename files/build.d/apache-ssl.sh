set -e
sed -i 's/\/etc\/ssl\/apache2\/server.crt/\/etc\/ssl\/certs\/localhost\.crt/g' /etc/apache2/vhosts.d/00_default_ssl_vhost.conf
sed -i 's/\/etc\/ssl\/apache2\/server.key/\/etc\/ssl\/private\/localhost\.key/g' /etc/apache2/vhosts.d/00_default_ssl_vhost.conf
