ARG CF_SRC_OS_IMAGE

FROM ${CF_SRC_OS_IMAGE}

#
ARG CF_CPUARCH_DEB_DIST
ARG CF_DEBIAN_RELEASE
ARG CF_DEBIAN_VERSION
ENV CF_CPUARCH_DEB_DIST=${CF_CPUARCH_DEB_DIST}
ENV CF_DEBIAN_RELEASE=${CF_DEBIAN_RELEASE}
ENV CF_DEBIAN_VERSION=${CF_DEBIAN_VERSION}

#
ENV CF_WEBROOT=/var/www/html

#
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
				graphicsmagick \
				cron \
				sudo \
				openssl \
			# apache2 packages
				apache2
	# forward request and error logs to docker log collector
	#	ln -sf /dev/stdout /var/log/apache2/access.log \
	#	&& ln -sf /dev/stderr /var/log/apache2/error.log

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

#
COPY files/start.sh /start.sh

RUN \
	chown root:root \
			/start.sh \
	&& chmod 700 \
			/start.sh

# SSL Cert/Key script
COPY \
	files/sslgen.sh \
	files/pwgen.sh \
	/root/

RUN \
	mkdir /etc/ssl/host-keys /etc/ssl/host-certs \
	&& mkdir /etc/ssl/host-keys-internal /etc/ssl/host-certs-internal \
	&& mkdir /var/www/letsencrypt_webroot \
	&& chmod 755 \
			/root/sslgen.sh \
			/root/pwgen.sh \
	&& chown root:root \
			/root/sslgen.sh \
			/root/pwgen.sh

# En-/disable Apache modules
RUN \
	a2enmod rewrite \
	&& a2enmod actions proxy_fcgi setenvif alias

# remove default sites
RUN \
	rm -f \
			/etc/apache2/sites-available/* \
			/etc/apache2/sites-enabled/* \
	|| echo -n

# copy new default sites
COPY files/apache/*.conf /etc/apache2/sites-available/

RUN \
	chmod 644 /etc/apache2/sites-available/* \
	&& chown root:root /etc/apache2/sites-available/* \
	&& mkdir /root/apache-defaults \
	&& cp /etc/apache2/sites-available/* /root/apache-defaults/

# add helper scripts
ADD files/helpers /opt/

RUN \
	ln -s /opt/remdotfiles.sh /usr/local/bin/remdotfiles \
	&& ln -s /opt/css_js_minimize.sh /usr/local/bin/css_js_minimize

# enable default site
RUN a2ensite 000-default-http.conf

#
ENV CF_WEBROOT_SITE=site-html

RUN \
	mkdir ${CF_WEBROOT}/${CF_WEBROOT_SITE} \
	&& chmod u=rwx,g=rwxs,o= ${CF_WEBROOT}/${CF_WEBROOT_SITE} \
	&& mv ${CF_WEBROOT}/index.html ${CF_WEBROOT}/${CF_WEBROOT_SITE}/

#
EXPOSE 80

WORKDIR ${CF_WEBROOT}

VOLUME /var/www/html
VOLUME /var/log/apache2
VOLUME /etc/apache2/sites-available
VOLUME /etc/apache2/sites-enabled
VOLUME /etc/ssl/host-certs
VOLUME /etc/ssl/host-keys

CMD ["/start.sh"]
