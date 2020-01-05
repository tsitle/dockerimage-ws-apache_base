ARG CF_DEBIAN_RELEASE
ARG CF_DEBIAN_VERSION
ARG CF_CPUARCH_DEB_DIST

FROM tsle/os-debian-${CF_DEBIAN_RELEASE}-${CF_CPUARCH_DEB_DIST}:${CF_DEBIAN_VERSION}

ENV CF_WEBROOT=/var/www/html

ENV DEBIAN_FRONTEND=noninteractive

RUN \
	apt-get update \
	&& apt-get upgrade -y \
	&& apt-get dist-upgrade -y \
	&& apt-get install -y --no-install-recommends \
			apt-transport-https \
			gnupg2 \
	&& if [ ! -d /etc/apt/sources.list.d ]; then mkdir -p /etc/apt/sources.list.d/; fi

RUN \
	# install packages
		apt-get update \
		&& apt-get install -y --no-install-recommends \
			# additional packages \
				procps \
				graphicsmagick \
				cron \
			# apache2 packages
				apache2
	# forward request and error logs to docker log collector
	#	ln -sf /dev/stdout /var/log/apache2/access.log \
	#	&& ln -sf /dev/stderr /var/log/apache2/error.log

#
COPY files/start.sh /start.sh

# remove default sites
RUN \
	rm -f /etc/apache2/sites-enabled/*

# En-/disable Apache modules
RUN \
	a2enmod rewrite \
	&& a2enmod actions proxy_fcgi setenvif alias

#
RUN \
	chown root:root \
			/start.sh \
	&& chmod 700 \
			/start.sh

# copy config files
COPY files/apache/000-default.conf /etc/apache2/sites-available/

# add helper scripts
ADD files/helpers /opt/

RUN \
	ln -s /opt/remdotfiles.sh /usr/local/bin/remdotfiles \
	&& ln -s /opt/css_js_minimize.sh /usr/local/bin/css_js_minimize

# enable default site
RUN a2ensite 000-default.conf

#
ENV CF_WEBROOT_SITE=site-html

RUN \
	mkdir ${CF_WEBROOT}/${CF_WEBROOT_SITE} \
	&& chmod u=rwx,g=rwxs,o= ${CF_WEBROOT}/${CF_WEBROOT_SITE} \
	&& mv ${CF_WEBROOT}/index.html ${CF_WEBROOT}/${CF_WEBROOT_SITE}/

#
RUN \
	apt-get --quiet --yes autoclean \
	&& apt-get --quiet --yes autoremove \
	&& apt-get --quiet --yes clean \
	&& rm -rf \
			/usr/share/man \
			/usr/share/doc \
			/usr/share/icons \
			/usr/share/poppler \
			/usr/share/mime \
			/var/lib/apt/lists*

#
ENV DEBIAN_FRONTEND=dialog

EXPOSE 80

WORKDIR ${CF_WEBROOT}

VOLUME /var/www/html
VOLUME /var/log/apache2

CMD ["/start.sh"]
