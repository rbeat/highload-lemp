#!/bin/bash

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Please switch to the root user."
    exit 1
fi

# Function to echo tasks in yellow
echo_task() {
  echo -e "\033[1;33m===== TASK $1: $2 =====\033[0m"
}

# Function to check the exit code and exit the script if non-zero
check_exit_code() {
  if [ $? -ne 0 ]; then
    echo -e "\033[1;31mERROR: Task $1 failed. Exiting script.\033[0m"
    exit 1
  fi
}

# Disable user prompt
export DEBIAN_FRONTEND=noninteractive

echo_task 1/40 "Update list of available packages"
apt update -y -q
check_exit_code 1

echo_task 2/40 "Update installed packages"
apt upgrade -y
check_exit_code 2

echo_task 3/40 "Install common development packages"
apt install -y -q zip unzip fail2ban htop sqlite3 nload mlocate nano memcached software-properties-common gnupg2 wget
check_exit_code 3

echo_task 4/40 "Install PHP 8.3 and necessary extensions"
wget https://packages.sury.org/php/apt.gpg -O /etc/apt/trusted.gpg.d/sury-php.gpg
check_exit_code 4.1
sh -c 'echo "deb [signed-by=/etc/apt/trusted.gpg.d/sury-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
check_exit_code 4.2
apt update -y
check_exit_code 4.3
apt install -y -q php8.3 php8.3-curl php8.3-fpm php8.3-gd php8.3-mbstring php8.3-opcache php8.3-xml php8.3-sqlite3 php8.3-mysql php-imagick
check_exit_code 4.4

echo_task 5/40 "Create backup directories"
now=$(date +"%Y-%m-%d_%H-%M-%S")
mkdir -p /backup/$now/nginx/ /backup/$now/php/ /backup/$now/mysql/
check_exit_code 5

echo_task 6/40 "Backup previous NGINX configuration"
cp -r /etc/nginx/ /backup/$now/nginx/
check_exit_code 6

echo_task 7/40 "Backup previous PHP configuration"
cp -r /etc/php/ /backup/$now/php/
check_exit_code 7

echo_task 8/40 "Backup previous MySQL configuration"
cp -r /etc/mysql/ /backup/$now/mysql/
check_exit_code 8

echo_task 9/40 "Remove previous NGINX installation"
apt purge -y -q nginx-core nginx-common nginx
check_exit_code 9
apt autoremove -y -q
check_exit_code 9.1

echo_task 10/40 "Add NGINX repository"
echo "deb http://nginx.org/packages/debian/ bullseye nginx" > /etc/apt/sources.list.d/nginx.list
wget https://nginx.org/keys/nginx_signing.key -O /etc/apt/trusted.gpg.d/nginx_signing.asc
check_exit_code 10

echo_task 11/40 "Update package list"
apt update -y -q
check_exit_code 11

echo_task 12/40 "Install NGINX 1.26.1"
apt install -y -q nginx=1.26.1-1~bullseye
check_exit_code 6

echo_task 13/40 "Prepare for NGINX Brotli Compilation"
apt install -y cmake build-essential libssl-dev libpcre3 libpcre3-dev
check_exit_code 13


echo_task 14/40 "Disable external access to PHP-FPM scripts"
sed -i "s/^;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/8.3/fpm/php.ini
check_exit_code 14

echo_task 15/40 "Create NGINX conf.d directory"
mkdir -p /etc/nginx/conf.d
check_exit_code 15

echo_task 16/40 "Download blacklist and block IPs for NGINX"
wget -O /etc/nginx/conf.d/blacklist.conf https://raw.githubusercontent.com/mariusv/nginx-badbot-blocker/master/blacklist.conf
check_exit_code 16
wget -O /etc/nginx/conf.d/blockips.conf https://raw.githubusercontent.com/mariusv/nginx-badbot-blocker/master/blockips.conf
check_exit_code 16.1

echo_task 17/40 "Create default site configuration for NGINX"
mkdir -p /etc/nginx/sites-enabled
mkdir -p /etc/nginx/sites-available
wget -O /etc/nginx/sites-available/default.conf https://raw.githubusercontent.com/rbeat/highload-lemp/debian-11/default.conf
ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf
check_exit_code 17

echo_task 18/40 "Create fastcgi.conf for NGINX"
echo -e 'fastcgi_param  SCRIPT_FILENAME    $document_root$fastcgi_script_name;\nfastcgi_param  QUERY_STRING       $query_string;\nfastcgi_param  REQUEST_METHOD     $request_method;\nfastcgi_param  CONTENT_TYPE       $content_type;\nfastcgi_param  CONTENT_LENGTH     $content_length;\n\nfastcgi_param  SCRIPT_NAME        $fastcgi_script_name;\nfastcgi_param  REQUEST_URI        $request_uri;\nfastcgi_param  DOCUMENT_URI       $document_uri;\nfastcgi_param  DOCUMENT_ROOT      $document_root;\nfastcgi_param  SERVER_PROTOCOL    $server_protocol;\nfastcgi_param  HTTPS              $https if_not_empty;\n\nfastcgi_param  GATEWAY_INTERFACE  CGI/1.1;\nfastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;\n\nfastcgi_param  REMOTE_ADDR        $remote_addr;\nfastcgi_param  REMOTE_PORT        $remote_port;\nfastcgi_param  SERVER_ADDR        $server_addr;\nfastcgi_param  SERVER_PORT        $server_port;\nfastcgi_param  SERVER_NAME        $server_name;\n\n# PHP only, required if PHP was built with --enable-force-cgi-redirect\nfastcgi_param  REDIRECT_STATUS    200;' > /etc/nginx/fastcgi.conf
check_exit_code 18

echo_task 19/40 "Create fastcgi-php.conf for NGINX"
echo -e '# regex to split $uri to $fastcgi_script_name and $fastcgi_path\nfastcgi_split_path_info ^(.+\.php)(/.+)$;\n\n# Check that the PHP script exists before passing it\ntry_files $fastcgi_script_name =404;\n\n# Bypass the fact that try_files resets $fastcgi_path_info\n# see: http://trac.nginx.org/nginx/ticket/321\nset $path_info $fastcgi_path_info;\nfastcgi_param PATH_INFO $path_info;\n\nfastcgi_index index.php;\ninclude fastcgi.conf;' > /etc/nginx/fastcgi-php.conf
check_exit_code 19

echo_task 20/40 "Create nginx.conf"
wget -O /etc/nginx/nginx.conf https://raw.githubusercontent.com/rbeat/highload-lemp/debian-11/nginx.conf
check_exit_code 20

echo_task 21/40 "Tweak memcached configuration"
sed -i "s/^-p 11211/#-p 11211/" /etc/memcached.conf
check_exit_code 21
sed -i "s/^-l 127.0.0.1/#-l 127.0.0.1/" /etc/memcached.conf
check_exit_code 21.1
echo -e "-s /tmp/memcached.sock" >> /etc/memcached.conf
echo -e "-a 775" >> /etc/memcached.conf
check_exit_code 21.2

echo_task 22/40 "Restart memcached service"
service memcached restart
check_exit_code 22

echo_task 23/40 "Add repository for MariaDB 10.6"
wget https://mariadb.org/mariadb_release_signing_key.asc -O /etc/apt/trusted.gpg.d/mariadb_release_signing_key.asc
check_exit_code 23
add-apt-repository 'deb [arch=amd64] http://mirror.aarnet.edu.au/pub/MariaDB/repo/10.6/debian bullseye main'
check_exit_code 23.1

echo_task 24/40 "Update package list for MariaDB"
apt update -y -q
check_exit_code 24

echo_task 25/40 "Configure and install MariaDB"
password=$(hostname | md5sum | awk '{print $1}')
debconf-set-selections <<< "mariadb-server mysql-server/root_password password $password"
debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $password"
apt install -y -q mariadb-server
check_exit_code 25

echo_task 26/40 "Add custom configuration for MySQL"
echo -e "\n[mysqld]\nmax_connections=24\nconnect_timeout=10\nwait_timeout=10\nthread_cache_size=24\nsort_buffer_size=1M\njoin_buffer_size=1M\ntmp_table_size=8M\nmax_heap_table_size=1M\nbinlog_cache_size=8M\nbinlog_stmt_cache_size=8M\nkey_buffer_size=1M\ntable_open_cache=64\nread_buffer_size=1M\nquery_cache_limit=1M\nquery_cache_size=8M\nquery_cache_type=1\ninnodb_buffer_pool_size=8M\ninnodb_open_files=1024\ninnodb_io_capacity=1024\ninnodb_buffer_pool_instances=1" >> /etc/mysql/my.cnf
check_exit_code 26

echo_task 27/40 "Write down current password for MariaDB in my.cnf"
echo -e "\n[client]\nuser = root\npassword = $password" >> /etc/mysql/my.cnf
check_exit_code 27

echo_task 28/40 "Restart MariaDB"
service mysql restart
check_exit_code 28

echo_task 29/40 "Install MySQLTuner"
apt install -y -q mysqltuner
check_exit_code 29

echo_task 30/40 "Create default folder for future websites"
mkdir -p /var/www/test.com
check_exit_code 30

echo_task 31/40 "Create Hello World page"
echo -e "<html>\n<body>\n<h1>Hello World!<h1>\n</body>\n</html>" > /var/www/test.com/index.html
check_exit_code 31

echo_task 32/40 "Create opcache page"
wget -O /var/www/test.com/opcache.php https://raw.githubusercontent.com/rlerdorf/opcache-status/master/opcache.php
check_exit_code 32

echo_task 33/40 "Create phpinfo page"
echo -e "<?php phpinfo();" > /var/www/test.com/info.php
check_exit_code 33

echo_task 34/40 "Give NGINX permissions to access websites"
chown -R www-data:www-data /var/www/*
check_exit_code 34

echo_task 35/40 "Maximize the limits of file system usage"
echo -e "*       soft    nofile  1000000" >> /etc/security/limits.conf
echo -e "*       hard    nofile  1000000" >> /etc/security/limits.conf
check_exit_code 35

echo_task 36/40 "Switch to ondemand state of PHP-FPM"
sed -i "s/^pm = .*/pm = ondemand/" /etc/php/8.3/fpm/pool.d/www.conf
check_exit_code 36

echo_task 37/40 "Calculate and set number of children for PHP-FPM"
ram=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
free=$(((ram/1024)-128-256-8))
php=$(((free/32)))
children=$(printf %.0f $php)
sed -i "s/^pm.max_children = .*/pm.max_children = $children/" /etc/php/8.3/fpm/pool.d/www.conf
check_exit_code 37
sed -i "s/^pm.start_servers = .*/;pm.start_servers = 5/" /etc/php/8.3/fpm/pool.d/www.conf
check_exit_code 37.1
sed -i "s/^pm.min_spare_servers = .*/;pm.min_spare_servers = 2/" /etc/php/8.3/fpm/pool.d/www.conf
check_exit_code 37.2
sed -i "s/^pm.max_spare_servers = .*/;pm.max_spare_servers = 2/" /etc/php/8.3/fpm/pool.d/www.conf
check_exit_code 37.3
sed -i "s/^;pm.max_requests = .*/pm.max_requests = 400/" /etc/php/8.3/fpm/pool.d/www.conf
check_exit_code 37.4
sed -i "s/^;pm.process_idle_timeout = .*/pm.process_idle_timeout = 10s;/" /etc/php/8.3/fpm/pool.d/www.conf
check_exit_code 37.5
sed -i "s/^;pm.status_path = \/status/pm.status_path = \/status/" /etc/php/8.3/fpm/pool.d/www.conf
check_exit_code 37.6
sed -i "s/^;ping.path = \/ping/ping.path = \/ping/" /etc/php/8.3/fpm/pool.d/www.conf
check_exit_code 37.7

echo_task 38/40 "Enable PHP-FPM Opcache"
sed -i "s/^;opcache.enable=0/opcache.enable=1/" /etc/php/8.3/fpm/php.ini
check_exit_code 38
sed -i "s/^;opcache.memory_consumption=64/opcache.memory_consumption=64/" /etc/php/8.3/fpm/php.ini
check_exit_code 38.1
sed -i "s/^;opcache.interned_strings_buffer=4/opcache.interned_strings_buffer=16/" /etc/php/8.3/fpm/php.ini
check_exit_code 38.2
sed -i "s/^;opcache.max_accelerated_files=2000/opcache.max_accelerated_files=65536/" /etc/php/8.3/fpm/php.ini
check_exit_code 38.3
sed -i "s/^;opcache.use_cwd=1/opcache.use_cwd=1/" /etc/php/8.3/fpm/php.ini
check_exit_code 38.4
sed -i "s/^;opcache.validate_timestamps=1/opcache.validate_timestamps=1/" /etc/php/8.3/fpm/php.ini
check_exit_code 38.5
sed -i "s/^;opcache.revalidate_freq=2/opcache.revalidate_freq=2/" /etc/php/8.3/fpm/php.ini
check_exit_code 38.6
sed -i "s/^;opcache.save_comments=1/opcache.save_comments=0/" /etc/php/8.3/fpm/php.ini
check_exit_code 38.7
sed -i "s/^;opcache.fast_shutdown=0/opcache.fast_shutdown=1/" /etc/php/8.3/fpm/php.ini
check_exit_code 38.8
sed -i "s/^;opcache.force_restart_timeout=180/opcache.force_restart_timeout=30/" /etc/php/8.3/fpm/php.ini
check_exit_code 38.9

echo_task 39/40 "Compile NGINX Brotli and re-install NGINX"
rm -rf /tmp/build
mkdir -p /tmp/build
cd /tmp/build
git clone --recurse-submodules -j8 https://github.com/google/ngx_brotli
check_exit_code 39.1
cd ngx_brotli/deps/brotli
mkdir out && cd out
check_exit_code 39.2
cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DCMAKE_C_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_CXX_FLAGS="-Ofast -m64 -march=native -mtune=native -flto -funroll-loops -ffunction-sections -fdata-sections -Wl,--gc-sections" -DCMAKE_INSTALL_PREFIX=./installed ..
check_exit_code 39.3
cmake --build . --config Release --target brotlienc
check_exit_code 39.4
cd /tmp/build
wget http://nginx.org/download/nginx-1.26.1.tar.gz
check_exit_code 39.5
tar -xvf nginx-1.26.1.tar.gz 
check_exit_code 39.6
cd nginx-1.26.1
echo "$(nginx -V 2>&1 | grep 'configure arguments:' | sed -e 's/configure arguments://;s/--with-cc-opt="[^"]*"//g;s/--with-ld-opt="[^"]*"//g')" > args.txt
check_exit_code 39.7
echo "./configure ""`cat args.txt`"" --add-dynamic-module=../ngx_brotli" > a.sh
bash a.sh
check_exit_code 39.8
make
check_exit_code 39.9
sudo make install
check_exit_code 39.9.1
rm -rf /tmp/build
mkdir -p /etc/nginx/sites-enabled
mkdir -p /etc/nginx/sites-available
if [ ! -f /etc/nginx/sites-enabled/default.conf ]; then
  wget -O /etc/nginx/sites-available/default.conf https://raw.githubusercontent.com/rbeat/highload-lemp/debian-11/default.conf
  ln -s /etc/nginx/sites-available/default.conf /etc/nginx/sites-enabled/default.conf
fi

echo_task 40/40 "Reload Nginx and PHP-FPM"
systemctl start nginx.service
check_exit_code 40
systemctl reload nginx
check_exit_code 40.1
systemctl start php8.3-fpm
check_exit_code 40.2
systemctl reload php8.3-fpm
check_exit_code 40.3