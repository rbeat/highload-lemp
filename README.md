# Highload LEMP Installation

This bash script will install LEMP stack on your server and configure it to maximize its performance of website serving.

## Software 
* NGINX 1.26.1 with fresh ngx-brotli
* PHP 8.3
* MariaDB 10.6 _(if it ain't broke - don't fix it)_ w/ MySQLTune
* OPCache (latest for the selected distro)

## Features
* All-in-one one "click" installation of the [LEMP](https://en.wikipedia.org/wiki/LAMP_(software_bundle)) environment
* [NGINX](https://launchpad.net/~hda-me/+archive/ubuntu/nginx-stable) will be installed with the ability to dynamically load or disable any preloaded module
* [Backup](https://gist.github.com/sutlxwhx/717efdfadd8052d456c2e4da16b0163b) will be created for your current NGINX, PHP and MySQL / MariaDB installations
* Some core settings of [NGINX](https://nginx.org/en/docs/http/ngx_http_core_module.html) and [MariaDB](https://mariadb.com/kb/en/library/server-system-variables/) that are often underestimated are configured properly
* [OPcache](http://php.net/manual/en/book.opcache.php) is enabled and configured for PHP-FPM 
* [Monit](https://mmonit.com/monit/) will be configured to watch after SSH, NGINX, PHP and MySQL / MariaDB and restart them in case of an emergency
* This configuration was tested in heavy loaded environment (>500k requests to a webserver a day) more then six months straight
* Don't struggle anymore with adding new server blocks to NGINX when you add new websites to your server

## Getting started
Every command is well commented so you will know what  happens after each line of the code.

## Requirements
* Check branches to see if your OS is supported
* This script utilises **root** user privileges. If you run it from another user you need to add this user to sudoers group and prepend sudo to all commands in the script.

## Usage

Select the needed branch for your OS and run the script

LEMP will be configured in such a way that it will try to find a folder which is identical to a website name in your /var/www/ directory.
<br/>For example if you created an A-record in your DNS panel where you pointed '@' name of 'test.com' domain to '1.2.3.4' IP adress of your server and you try to access 'test.com' LEMP will try to serve index.php or index.html from the /var/www/test.com directory as an initial response.

**MariaDB password** is generated using md5 hash of your server hostname and will be put in your /etc/mysql/my.cnf after [client] directive. 

## Example Files

These files will be created in order to help you understand how this installation works:
* "Hello World" website in /var/www/test.com 
* phpinfo(); file at /var/www/test.com/info.php
* [opcache.php](https://github.com/rlerdorf/opcache-status) at /var/www/test.com/opcache.php

## Verification

You can verify the installation with the info.php file or using the following commands.
<br/>This will show current NGINX version and all installed NGINX modules:
```shell
nginx -V
```
These will show current PHP-FPM version all installed PHP-FPM modules:
```shell
php -v
php -m
```
These will show current MariaDB version and promt EXIT; command if you entered MariaDB shell:
```shell
mysql -v
EXIT;
```red MariaDB shell:
```shell
mysql -v
EXIT;
```

## Licensing

The code in this project is licensed under Apache License 2.0