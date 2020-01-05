# Apache2 Webserver Docker Image for AARCH64, ARMv7l, X86 and X64

For hosting static HTML websites.

## Inheritance and added packages
- Debian Stretch
	- Apache 2.4
	- graphicsmagick
	- cron
	- helper scripts (remdotfiles and css_js_minimize)

## Webserver TCP Port
The webserver is listening only on TCP port 80 by default.

## Docker Container usage
See the related GitHub repository [https://github.com/tsitle/dockercontainer-ws-apache\_base](https://github.com/tsitle/dockercontainer-ws-apache_base)

## Docker Container configuration
- CF\_PROJ\_PRIMARY\_FQDN [string]: FQDN for website (e.g. "mywebsite.localhost")
- CF\_SET\_OWNER\_AND\_PERMS\_WEBROOT [bool]: Recursively chown and chmod CF\_WEBROOT?
- CF\_WWWDATA\_USER\_ID [int]: User-ID for www-data
- CF\_WWWDATA\_GROUP\_ID [int]: Group-ID for www-data
- CF\_ENABLE\_CRON [bool]: Enable cron service?
- CF\_LANG [string]: Language to use (en\_EN.UTF-8 or de\_DE.UTF-8)
- CF\_TIMEZONE [string]: Timezone (e.g. 'Europe/Berlin')

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
    restart: unless-stopped
    stdin_open: false
    tty: false
```
