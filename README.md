# Apache2 Webserver Docker Image for AARCH64, ARMv7l, X86 and X64

For hosting static HTML websites.

## Inheritance and added packages
- Debian Buster
	- Apache 2.4
	- graphicsmagick
	- cron
	- unzip
	- sudo
	- openssl
	- helper scripts (remdotfiles and css_js_minimize)

## Webserver TCP Port
The webserver is listening only on TCP port 80 by default.

## Docker Container usage
See the related GitHub repository [https://github.com/tsitle/dockercontainer-ws-apache\_base](https://github.com/tsitle/dockercontainer-ws-apache_base)

## Docker Container configuration
- CF\_PROJ\_PRIMARY\_FQDN [string]: FQDN for website (e.g. "mywebsite.localhost") (default: empty)
- CF\_SET\_OWNER\_AND\_PERMS\_WEBROOT [bool]: Recursively chown and chmod CF\_WEBROOT? (default: false)
- CF\_WWWDATA\_USER\_ID [int]: User-ID for www-data (default: 33)
- CF\_WWWDATA\_GROUP\_ID [int]: Group-ID for www-data (default: 33)
- CF\_ENABLE\_CRON [bool]: Enable cron service? (default: false)
- CF\_LANG [string]: Language to use (en\_EN.UTF-8 or de\_DE.UTF-8) (default: empty)
- CF\_TIMEZONE [string]: Timezone (e.g. 'Europe/Berlin') (default: empty)
- CF\_ENABLE\_HTTP [bool]: Enable HTTP for Apache? (default: true)
- CF\_CREATE\_DEFAULT\_HTTP\_SITE [bool]: Create default HTTP Virtual Host for Apache? (default: true)
- CF\_ENABLE\_HTTPS [bool]: Enable HTTPS/SSL for Apache? (default: false)
- CF\_CREATE\_DEFAULT\_HTTPS\_SITE [bool]: Create default HTTPS/SSL Virtual Host for Apache? (default: true)
- CF\_SSLCERT\_GROUP\_ID [int]: Group-ID for ssl-cert (default: 102)
- CF\_DEBUG\_SSLGEN\_SCRIPT [bool]: Enable debug out for sslgen.sh?
- CF\_CSR\_SUBJECT\_COUNTRY [string]: For auto-generated SSL Certificates (default: DE)
- CF\_CSR\_SUBJECT\_STATE [string]: For auto-generated SSL Certificates (default: SAX)
- CF\_CSR\_SUBJECT\_LOCATION [string]: For auto-generated SSL Certificates (default: LE)
- CF\_CSR\_SUBJECT\_ORGANIZ [string]: For auto-generated SSL Certificates (default: The IT Company)
- CF\_CSR\_SUBJECT\_ORGUNIT [string]: For auto-generated SSL Certificates (default: IT)

## Using cron
You'll need to create the crontab file `./mpcron/root` and then add some task to the file:

```
# the following command will be executed as 'root'
* *    *   *   *     cd /var/www/html/; tar cf backup.tar site-html/> /dev/null 2>&1
```

Now you could enable cron in your docker-compose.yaml file like this:

```
version: '3.5'
services:
  apache:
    image: "ws-apache-base-<ARCH>:<VERSION>"
    ports:
      - "80:80"
    volumes:
      - "$PWD/mpweb:/var/www/html"
      - "$PWD/mpcron/root:/var/spool/cron/crontabs/root"
    environment:
      - CF_PROJ_PRIMARY_FQDN=example-host.localhost
      - CF_SET_OWNER_AND_PERMS_WEBROOT=true
      - CF_ENABLE_CRON=true
      - CF_LANG=de_DE.UTF-8
      - CF_TIMEZONE=Europe/Berlin
      - CF_ENABLE_HTTPS=false
    restart: unless-stopped
    stdin_open: false
    tty: false
```
