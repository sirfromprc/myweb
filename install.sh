#!/bin/bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin:/opt/homebrew/bin
export PATH
# LANG=en_US.UTF-8
is64bit=`getconf LONG_BIT`

{

if [ -f /etc/motd ];then
    echo "welcome to mdserver-web panel" > /etc/motd
fi

startTime=`date +%s`

_os=`uname`
echo "use system: ${_os}"

if [ ${_os} == "Darwin" ]; then
	OSNAME='macos'
elif grep -Eqi "openSUSE" /etc/*-release; then
	OSNAME='opensuse'
	zypper refresh
	zypper install cron wget curl zip unzip
elif grep -Eqi "FreeBSD" /etc/*-release; then
	OSNAME='freebsd'
	pkg install -y wget curl zip unzip unrar rar
elif grep -Eqi "EulerOS" /etc/*-release || grep -Eqi "openEuler" /etc/*-release; then
	OSNAME='euler'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "CentOS" /etc/issue || grep -Eqi "CentOS" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "Fedora" /etc/issue || grep -Eqi "Fedora" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "Rocky" /etc/issue || grep -Eqi "Rocky" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "AlmaLinux" /etc/issue || grep -Eqi "AlmaLinux" /etc/*-release; then
	OSNAME='rhel'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "Amazon Linux" /etc/issue || grep -Eqi "Amazon Linux" /etc/*-release; then
	OSNAME='amazon'
	yum install -y wget curl zip unzip tar crontabs
elif grep -Eqi "Debian" /etc/issue || grep -Eqi "Debian" /etc/os-release; then
	OSNAME='debian'
	apt update -y
	apt install -y wget curl zip unzip tar cron
elif grep -Eqi "Ubuntu" /etc/issue || grep -Eqi "Ubuntu" /etc/os-release; then
	OSNAME='ubuntu'
	apt update -y
	apt install -y wget curl zip unzip tar cron
else
	OSNAME='unknow'
fi

if [ "$EUID" -ne 0 ] && [ "$OSNAME" != "macos" ];then 
	echo "Please run as root!"
 	exit
fi


# HTTP_PREFIX="https://"
# LOCAL_ADDR=common
# ping  -c 1 github.com > /dev/null 2>&1
# if [ "$?" != "0" ];then
# 	LOCAL_ADDR=cn
# 	HTTP_PREFIX="https://mirror.ghproxy.com/"
# fi

HTTP_PREFIX="https://"
LOCAL_ADDR=common
cn=$(curl -fsSL -m 10 -s http://ipinfo.io/json | grep "\"country\": \"CN\"")
if [ ! -z "$cn" ] || [ "$?" == "0" ] ;then
	LOCAL_ADDR=cn
    HTTP_PREFIX="https://mirror.ghproxy.com/"
fi

echo "local:${LOCAL_ADDR}"

if [ $OSNAME != "macos" ];then
	if id www &> /dev/null ;then 
	    echo ""
	else
	    groupadd www
		useradd -g www -s /usr/sbin/nologin www
	fi

	mkdir -p /www/server
	mkdir -p /www/wwwroot
	mkdir -p /www/wwwlogs
	mkdir -p /www/backup/database
	mkdir -p /www/backup/site

	# https://cdn.jsdelivr.net/gh/midoks/mdserver-web@latest/scripts/install.sh
	if [ ! -d /www/server/mdserver-web ];then
		if [ "$LOCAL_ADDR" == "common" ];then
			curl --insecure -sSLo /tmp/master.zip ${HTTP_PREFIX}github.com/midoks/mdserver-web/archive/refs/heads/master.zip
			cd /tmp && unzip /tmp/master.zip
			mv -f /tmp/mdserver-web-master /www/server/mdserver-web
			rm -rf /tmp/master.zip
			rm -rf /tmp/mdserver-web-master
			rm -rf /www/server/mdserver-web/route/templates/default/layout.html
			curl -sSLo /www/server/mdserver-web/route/templates/default/layout.html https://raw.githubusercontent.com/sirfromprc/myweb/main/layout.html 			
		else
			# curl --insecure -sSLo /tmp/master.zip https://code.midoks.icu/midoks/mdserver-web/archive/master.zip
			wget --no-check-certificate -O /tmp/master.zip https://code.midoks.icu/midoks/mdserver-web/archive/master.zip
			cd /tmp && unzip /tmp/master.zip
			mv -f /tmp/mdserver-web /www/server/mdserver-web
			rm -rf /tmp/master.zip
			rm -rf /tmp/mdserver-web
			rm -rf /www/server/mdserver-web/route/templates/default/layout.html
			curl -sSLo /www/server/mdserver-web/route/templates/default/layout.html https://raw.githubusercontent.com/sirfromprc/myweb/main/layout.html
		fi

		
	fi

	# install acme.sh
	if [ ! -d /root/.acme.sh ];then
	    if [ "$LOCAL_ADDR" != "common" ];then
	        curl --insecure -sSLo /tmp/acme.tar.gz https://gitee.com/neilpang/acme.sh/repository/archive/master.tar.gz
	        tar xvzf /tmp/acme.tar.gz -C /tmp
	        cd /tmp/acme.sh-master
	        bash acme.sh install
	    fi

	    if [ ! -d /root/.acme.sh ];then
	        curl  https://get.acme.sh | sh
	    fi
	fi
fi

echo "use system version: ${OSNAME}"
if [ "${OSNAME}" == "macos" ];then
	curl --insecure -fsSL https://code.midoks.icu/midoks/mdserver-web/raw/branch/master/scripts/install/macos.sh | bash
else
	cd /www/server/mdserver-web && bash scripts/install/${OSNAME}.sh
fi

if [ "${OSNAME}" == "macos" ];then
	echo "macos end"
	exit 0
fi

cd /tmp
curl -o 2.3.tar.gz -L https://github.com/FRiCKLE/ngx_cache_purge/archive/2.3.tar.gz && tar -zxvf 2.3.tar.gz -C /www/server/source/
sed -i '/--with-http_stub_status_module/a \ \t--add-module=\/www\/server\/source\/ngx_cache_purge-2.3 \\' /www/server/mdserver-web/plugins/openresty/versions/1.25.3/install.sh

apt install libbrotli-dev -y
git clone https://github.com/google/ngx_brotli /www/server/source/ngx_brotli
cd /www/server/source/ngx_brotli && git submodule update --init
sed -i '/--with-http_stub_status_module/a \ \t--add-module=\/www\/server\/source\/ngx_brotli \\' /www/server/mdserver-web/plugins/openresty/versions/1.25.3/install.sh

cd
sed -i '/bash memcached\.sh install/a \ \tcd \${rootPath}\/plugins\/php\/versions\/common \&\& bash opcache\.sh install \${type}' /www/server/mdserver-web/plugins/php/install.sh
sed -i '/bash memcached\.sh install/a \ \tcd \${rootPath}\/plugins\/php\/versions\/common \&\& bash igbinary\.sh install \${type}' /www/server/mdserver-web/plugins/php/install.sh
sed -i '/bash memcached\.sh install/a \ \tcd \${rootPath}\/plugins\/php\/versions\/common \&\& bash imagemagick\.sh install \${type}' /www/server/mdserver-web/plugins/php/install.sh
sed -i '/bash memcached\.sh install/a \ \tcd \${rootPath}\/plugins\/php\/versions\/common \&\& bash fileinfo\.sh install \${type}' /www/server/mdserver-web/plugins/php/install.sh
mv /www/server/mdserver-web/plugins/openresty/conf/nginx.conf /www/server/mdserver-web/plugins/openresty/conf/nginx_origin.conf
curl -sSLo /www/server/mdserver-web/plugins/openresty/conf/nginx.conf https://raw.githubusercontent.com/sirfromprc/myweb/main/nginx.conf

sed -i '/authentication_policy/i skip-log-bin' /www/server/mdserver-web/plugins/mysql-apt/conf/my8.0.cnf
sed -i '/authentication_policy/i mysqlx=0' /www/server/mdserver-web/plugins/mysql-apt/conf/my8.0.cnf
sed -i '/authentication_policy/i log_timestamps = SYSTEM' /www/server/mdserver-web/plugins/mysql-apt/conf/my8.0.cnf
sed -i '/authentication_policy/i log_error_verbosity = 1' /www/server/mdserver-web/plugins/mysql-apt/conf/my8.0.cnf
sed -i '/authentication_policy/i \\t' /www/server/mdserver-web/plugins/mysql-apt/conf/my8.0.cnf
sed -i 's/log-bin=mysql-bin/#log-bin=mysql-bin/' /www/server/mdserver-web/plugins/mysql-apt/conf/my8.0.cnf
sed -i 's/(rdata.Innodb_buffer_pool_read_requests \/ (rdata.Innodb_buffer_pool_read_requests+rdata.Innodb_buffer_pool_reads))/((1 - (rdata.Innodb_buffer_pool_reads \/ rdata.Innodb_buffer_pool_read_requests)) * 100)/' /www/server/mdserver-web/plugins/mysql-apt/js/mysql-apt.js

# support caching_sha2_password,php8.0 unuseful
sed -i '/--enable-mysqlnd/a \ \t--with-openssl \\' /www/server/mdserver-web/plugins/php/versions/83/install.sh

# for php83
sed -i 's/LIBV=3.2.7/LIBV=3.2.16/' /www/server/mdserver-web/plugins/php/versions/common/igbinary.sh

# redis
sed -i 's/LIBV=5.3.7/LIBV=6.1.0/' /www/server/mdserver-web/plugins/php/versions/common/redis.sh
sed -i 's/bin\/php-config $OPTIONS/bin\/php-config $OPTIONS  --enable-redis-igbinary --enable-redis-zstd --enable-redis-lzf/' /www/server/mdserver-web/plugins/php/versions/common/redis.sh

echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
echo "fs.nr_open = 10000000" >> /etc/sysctl.conf
# disable ipv6 ra
echo "net.ipv6.conf.all.accept_ra = 0" >> /etc/sysctl.conf
echo "net.ipv6.conf.ens3.autoconf = 0" >> /etc/sysctl.conf
echo "net.ipv6.conf.ens3.accept_ra = 0" >> /etc/sysctl.conf
echo "net.ipv6.conf.all.autoconf = 0" >> /etc/sysctl.conf

sysctl -p
systemctl restart networking.service

# limits
cat >> /etc/security/limits.conf <<EOF
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536
* hard nproc 65000
* soft nproc 65000
EOF

sed -i '/Restart=on-failure/a LimitNOFILE=65535' /www/server/mdserver-web/plugins/openresty/init.d/openresty.service.tpl
sed -i '/Restart=on-failure/a LimitNOFILE=65535' /www/server/mdserver-web/plugins/redis/init.d/redis.service.tpl

timedatectl set-timezone Asia/Shanghai

# wordpress 
cat > /www/server/mdserver-web/rewrite/nginx/wordpress.conf <<EOF
location / {
    try_files \$uri \$uri/ /index.php?\$args;
} 

rewrite /wp-admin\$ \$scheme://\$host\$uri/ permanent;
EOF

cd /www/server/mdserver-web && bash cli.sh start
isStart=`ps -ef|grep 'gunicorn -c setting.py app:app' |grep -v grep|awk '{print $2}'`
n=0
while [ ! -f /etc/rc.d/init.d/mw ];
do
    echo -e ".\c"
    sleep 1
    let n+=1
    if [ $n -gt 20 ];then
    	echo -e "start mw fail"
    	exit 1
    fi
done

cd /www/server/mdserver-web && bash /etc/rc.d/init.d/mw stop
cd /www/server/mdserver-web && bash /etc/rc.d/init.d/mw start
cd /www/server/mdserver-web && bash /etc/rc.d/init.d/mw default

sleep 2
if [ ! -e /usr/bin/mw ]; then
	if [ -f /etc/rc.d/init.d/mw ];then
		ln -s /etc/rc.d/init.d/mw /usr/bin/mw
	fi
fi

endTime=`date +%s`
((outTime=(${endTime}-${startTime})/60))
echo -e "Time consumed:\033[32m $outTime \033[0mMinute!"

} 1> >(tee mw-install.log) 2>&1

echo -e "\nInstall completed. If error occurs, please contact us with the log file mw-install.log ."
echo "安装完毕，如果出现错误，请带上同目录下的安装日志 mw-install.log 联系我们反馈."
