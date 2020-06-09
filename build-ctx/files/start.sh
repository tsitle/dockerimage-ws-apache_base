#!/bin/bash

#
# by TS, May 2019
#

VAR_MYNAME="$(basename "$0")"

# ----------------------------------------------------------

# @param string $1 Message
#
# @return void
function _log_err() {
	local TMP_LOG_PATH="${LCFG_LOG_PATH:-/var/log}"
	echo "$VAR_MYNAME: $1" >/dev/stderr
	echo "$(date --rfc-3339=seconds) $VAR_MYNAME: $1" >> "$TMP_LOG_PATH/start_script.log"
}

# @param string $1 Message
#
# @return void
function _log_def() {
	local TMP_LOG_PATH="${LCFG_LOG_PATH:-/var/log}"
	echo "$VAR_MYNAME: $1"
	echo "$(date --rfc-3339=seconds) $VAR_MYNAME: $1" >> "$TMP_LOG_PATH/start_script.log"
}

# @return void
function _sleepBeforeAbort() {
	# to allow the user to see this message in 'docker logs -f CONTAINER' we wait before exiting
	_log_err "(sleeping 5s before aborting)"
	local TMP_CNT=0
	while [ $TMP_CNT -lt 5 ]; do
		sleep 1
		_log_err "(...)"
		TMP_CNT=$(( TMP_CNT + 1 ))
	done
	_log_err "(aborting now)"
	exit 1
}

# ----------------------------------------------------------

LCFG_LOG_PATH="/var/log"

_log_def "----------------"

# ----------------------------------------------------------

export HOST_IP=$(/sbin/ip route|awk '/default/ { print $3 }')
echo "$HOST_IP dockerhost" >> /etc/hosts

# ----------------------------------------------------------

LVAR_WS_IS_APACHE=false
[ -d /etc/apache2 ] && LVAR_WS_IS_APACHE=true
LVAR_WS_IS_NGINX=false
[ "$LVAR_WS_IS_APACHE" = "false" -a -d /etc/nginx ] && LVAR_WS_IS_NGINX=true
if [ "$LVAR_WS_IS_APACHE" != "true" -a "$LVAR_WS_IS_NGINX" != "true" ]; then
	_log_err "Error: could not determine webserver type. Aborting."
	_sleepBeforeAbort
fi

# ----------------------------------------------------------

CF_WEBROOT="${CF_WEBROOT:-/var/www/html}"
CF_WEBROOT_SITE="${CF_WEBROOT_SITE:-}"
CF_WEBROOT_SITE_ORG="${CF_WEBROOT_SITE_ORG:-}"

CF_PROJ_PRIMARY_FQDN="${CF_PROJ_PRIMARY_FQDN:-}"

CF_ENABLE_HTTP=${CF_ENABLE_HTTP:-true}
CF_ENABLE_HTTPS=${CF_ENABLE_HTTPS:-false}

CF_CREATE_DEFAULT_HTTP_SITE=${CF_CREATE_DEFAULT_HTTP_SITE:-false}
CF_CREATE_DEFAULT_HTTPS_SITE=${CF_CREATE_DEFAULT_HTTPS_SITE:-false}

CF_HTTPS_FQDN_DEFAULT="${CF_PROJ_PRIMARY_FQDN:-default.localhost}"

CF_WWWDATA_USER_ID=${CF_WWWDATA_USER_ID:-33}
CF_WWWDATA_GROUP_ID=${CF_WWWDATA_GROUP_ID:-33}

CF_WWWFPM_USER_ID=${CF_WWWFPM_USER_ID:-1000}
CF_WWWFPM_GROUP_ID=${CF_WWWFPM_GROUP_ID:-1000}

CF_SSLCERT_GROUP_ID=${CF_SSLCERT_GROUP_ID:-120}

CF_LANG="${CF_LANG:-}"
CF_TIMEZONE="${CF_TIMEZONE:-}"

CF_ENABLE_CRON=${CF_ENABLE_CRON:-false}
CF_SET_OWNER_AND_PERMS_WEBROOT=${CF_SET_OWNER_AND_PERMS_WEBROOT:-false}

# config file for PHP module XDebug is pre-configured for REMOTE_HOST=dockerhost
CF_ENABLE_XDEBUG=${CF_ENABLE_XDEBUG:-false}
CF_XDEBUG_REMOTE_HOST="${CF_XDEBUG_REMOTE_HOST:-}"

CF_PHPFPM_RUN_AS_WWWDATA=${CF_PHPFPM_RUN_AS_WWWDATA:-false}
CF_PHPFPM_ENABLE_OPEN_BASEDIR="${CF_PHPFPM_ENABLE_OPEN_BASEDIR:-true}"
CF_PHPFPM_UPLOAD_TMP_DIR="${CF_PHPFPM_UPLOAD_TMP_DIR:-/var/www/upload_tmp_dir/}"
CF_PHPFPM_PM_MAX_CHILDREN=${CF_PHPFPM_PM_MAX_CHILDREN:-5}
CF_PHPFPM_PM_START_SERVERS=${CF_PHPFPM_PM_START_SERVERS:-2}
CF_PHPFPM_PM_MIN_SPARE_SERVERS=${CF_PHPFPM_PM_MIN_SPARE_SERVERS:-1}
CF_PHPFPM_PM_MAX_SPARE_SERVERS=${CF_PHPFPM_PM_MAX_SPARE_SERVERS:-3}
CF_PHPFPM_UPLOAD_MAX_FILESIZE="${CF_PHPFPM_UPLOAD_MAX_FILESIZE:-100M}"
CF_PHPFPM_POST_MAX_SIZE="${CF_PHPFPM_POST_MAX_SIZE:-100M}"
CF_PHPFPM_MEMORY_LIMIT="${CF_PHPFPM_MEMORY_LIMIT:-512M}"
CF_PHPFPM_MAX_EXECUTION_TIME="${CF_PHPFPM_MAX_EXECUTION_TIME:-600}"
CF_PHPFPM_MAX_INPUT_TIME="${CF_PHPFPM_MAX_INPUT_TIME:-600}"
CF_PHPFPM_HTML_ERRORS=${CF_PHPFPM_HTML_ERRORS:-true}

# ----------------------------------------------------------

LCFG_WS_SITES_PATH_AVAIL=""
LCFG_WS_SITES_PATH_ENAB=""

LCFG_WS_SITECONF_DEF_HTTP=""
LCFG_WS_SITECONF_DEF_HTTPS=""
LCFG_WS_SITECONF_FEXT=""
LCFG_WS_SITECONF_ORG_PATH=""

if [ "$LVAR_WS_IS_APACHE" = "true" ]; then
	LCFG_LOG_PATH="/var/log/apache2"

	LCFG_WS_SITES_PATH_AVAIL="/etc/apache2/sites-available"
	LCFG_WS_SITES_PATH_ENAB="/etc/apache2/sites-enabled"

	LCFG_WS_SITECONF_DEF_HTTP="000-default-http.conf"
	LCFG_WS_SITECONF_DEF_HTTPS="000-default-https.conf"
	LCFG_WS_SITECONF_FEXT=".conf"
	LCFG_WS_SITECONF_ORG_PATH="/root/apache-defaults"
elif [ "$LVAR_WS_IS_NGINX" = "true" ]; then
	LCFG_LOG_PATH="/var/log/nginx"

	LCFG_WS_SITES_PATH_AVAIL="/etc/nginx/sites-available"
	LCFG_WS_SITES_PATH_ENAB="/etc/nginx/sites-enabled"

	LCFG_WS_SITECONF_DEF_HTTP="030-default-http"
	LCFG_WS_SITECONF_DEF_HTTPS="031-default-https"
	LCFG_WS_SITECONF_FEXT=""
	LCFG_WS_SITECONF_ORG_PATH="/root/nginx-defaults"
fi

LCFG_SSL_PATH_HOST_CERTS="/etc/ssl/host-certs"
LCFG_SSL_PATH_HOST_KEYS="/etc/ssl/host-keys"
LCFG_SSL_PATH_LETSENCRYPT_WEBROOT="/var/www/letsencrypt_webroot"

# ----------------------------------------------------------

# @param string $1 Username/Groupname
#
# @return void
function _removeUserAndGroup() {
	getent passwd "$1" >/dev/null 2>&1 && userdel -f "$1"
	getent group "$1" >/dev/null 2>&1 && groupdel "$1"
	return 0
}

# Change numeric IDs of user/group to user-supplied values
#
# @param string $1 Username/Groupname
# @param string $2 Numeric ID for User as string
# @param string $3 Numeric ID for Group as string
# @param string $4 optional: Additional Group-Memberships for User
#
# @return int EXITCODE
function _createUserGroup() {
	local TMP_NID_U="$2"
	local TMP_NID_G="$3"
	echo -n "$TMP_NID_U" | grep -q -E "^[0-9]*$" || {
		_log_err "Error: non-numeric User ID '$TMP_NID_U' supplied for '$1'. Aborting."
		return 1
	}
	echo -n "$TMP_NID_G" | grep -q -E "^[0-9]*$" || {
		_log_err "Error: non-numeric Group ID '$TMP_NID_G' supplied '$1'. Aborting."
		return 1
	}
	[ ${#TMP_NID_U} -gt 5 ] && {
		_log_err "Error: numeric User ID '$TMP_NID_U' for '$1' has more than five digits. Aborting."
		return 1
	}
	[ ${#TMP_NID_G} -gt 5 ] && {
		_log_err "Error: numeric Group ID '$TMP_NID_G' for '$1' has more than five digits. Aborting."
		return 1
	}
	[ $TMP_NID_U -eq 0 ] && {
		_log_err "Error: numeric User ID for '$1' may not be 0. Aborting."
		return 1
	}
	[ $TMP_NID_G -eq 0 ] && {
		_log_err "Error: numeric Group ID for '$1' may not be 0. Aborting."
		return 1
	}

	local TMP_ADD_G="$4"
	if [ -n "$TMP_ADD_G" ]; then
		echo -n "$TMP_ADD_G" | LC_ALL=C grep -q -E "^([0-9a-z_,]|-)*$" || {
			_log_err "Error: additional Group-Memberships '$TMP_ADD_G' container invalid characters. Aborting."
			return 1
		}
	fi

	_removeUserAndGroup "$1"

	getent passwd $TMP_NID_U >/dev/null 2>&1 && {
		_log_err "Error: numeric User ID '$TMP_NID_U' already exists. Aborting."
		return 1
	}
	getent group $TMP_NID_G >/dev/null 2>&1 && {
		_log_err "Error: numeric Group ID '$TMP_NID_G' already exists. Aborting."
		return 1
	}

	local TMP_ARG_ADD_GRPS=""
	[ -n "$TMP_ADD_G" ] && TMP_ARG_ADD_GRPS="-G $TMP_ADD_G"

	_log_def "Setting numeric user/group ID of '$1' to ${TMP_NID_U}/${TMP_NID_G}..."
	groupadd -g ${TMP_NID_G} "$1" || {
		_log_err "Error: could not create Group '$1'. Aborting."
		return 1
	}
	useradd -l -u ${TMP_NID_U} -g "$1" $TMP_ARG_ADD_GRPS -M -s /bin/false "$1" || {
		_log_err "Error: could not create User '$1'. Aborting."
		return 1
	}
	return 0
}

# ----------------------------------------------------------

# Create Upload directory for PHP-FPM
#
# @return void
function _createPhpFpmUploadDir() {
	local TMP_UPL_DIR="$(echo -n "$CF_PHPFPM_UPLOAD_TMP_DIR" | sed -e 's,/$,,g')"
	[ -d "$TMP_UPL_DIR" ] || mkdir "$TMP_UPL_DIR"
	if [ "$TMP_UPL_DIR" != "/tmp" -a "$TMP_UPL_DIR" != "/var/tmp" ]; then
		if [ "$CF_PHPFPM_RUN_AS_WWWDATA" != "true" ]; then
			chown wwwphpfpm:wwwphpfpm "$TMP_UPL_DIR" || return 1
		else
			chown www-data:www-data "$TMP_UPL_DIR" || return 1
		fi
		chmod u=rwx,g=rwxs,o= "$TMP_UPL_DIR"
	fi
}

# ----------------------------------------------------------

# @return int EXITCODE
function _setOwnerPermsWebroot() {
	local TMP_WEB_USER="www-data"
	local TMP_WEB_GROUP="www-data"
	if [ -n "$CF_PHP_FPM_VERSION" -a "$CF_PHPFPM_RUN_AS_WWWDATA" != "true" ]; then
		TMP_WEB_USER="wwwphpfpm"
		TMP_WEB_GROUP="wwwphpfpm"
	fi
	local TMP_WEBR_SITE="$CF_WEBROOT"
	[ -n "$CF_WEBROOT_SITE" -a -d "$CF_WEBROOT/$CF_WEBROOT_SITE" ] && TMP_WEBR_SITE="$TMP_WEBR_SITE/$CF_WEBROOT_SITE"
	_log_def "Chown'ing and chmod'ing $TMP_WEBR_SITE"
	_log_def "               - chmod u=rwx,g=rwx,o=rx '$TMP_WEBR_SITE'"
	chmod u=rwx,g=rwx,o=rx "$TMP_WEBR_SITE" || return 1
	chmod u=r,g=r,o=r "$TMP_WEBR_SITE" || return 1
	_log_def "               - find '$TMP_WEBR_SITE' -type d -exec chmod u=rwx,g=rwxs,o=rx"
	find "$TMP_WEBR_SITE" -type d -exec chmod u=rwx,g=rwxs,o=rx '{}' \; || return 1
	_log_def "               - find '$TMP_WEBR_SITE' -type f -exec chmod ug=rw,o=r"
	find "$TMP_WEBR_SITE" -type f -exec chmod ug=rw,o=r '{}' \; || return 1
	_log_def "               - chown $TMP_WEB_USER:$TMP_WEB_GROUP -R '$TMP_WEBR_SITE'"
	chown $TMP_WEB_USER:$TMP_WEB_GROUP -R "$TMP_WEBR_SITE" || return 1
	# for Neos CMS:
	[ -f "$TMP_WEBR_SITE/flow" ] && {
		_log_def "               - chmod ug+x '$TMP_WEBR_SITE/flow'"
		chmod ug+x "$TMP_WEBR_SITE/flow" || return 1
	}
	return 0
}

# ----------------------------------------------------------

# @return int EXITCODE
function _changeApacheWebroot() {
	_log_def "Setting webroot to '$CF_WEBROOT/$CF_WEBROOT_SITE'..."
	local TMP_WR_PATH_ORG=""
	if [ -n "$CF_WEBROOT_SITE_ORG" ]; then
		TMP_WR_PATH_ORG="$(echo -n "$CF_WEBROOT/$CF_WEBROOT_SITE_ORG" | sed -e 's/\//\\\//g')"
	else
		TMP_WR_PATH_ORG="$(echo -n "$CF_WEBROOT" | sed -e 's/\//\\\//g')"
	fi

	local TMP_DR_PATH="$CF_WEBROOT/$CF_WEBROOT_SITE"
	local TMP_WR_PATH="$CF_WEBROOT/$CF_WEBROOT_SITE"

	if [ "$CF_IS_FOR_NEOS_CMS" = "true" ]; then
		TMP_DR_PATH="$TMP_DR_PATH/Web"
	fi

	local TMP_DR_PATH_SED="$(echo -n "$TMP_DR_PATH" | sed -e 's/\//\\\//g')"
	local TMP_WR_PATH_SED="$(echo -n "$TMP_WR_PATH" | sed -e 's/\//\\\//g')"

	if [ -f $LCFG_WS_SITES_PATH_AVAIL/$LCFG_WS_SITECONF_DEF_HTTP ]; then
		sed -i \
				-e "s/<DOCROOT>/${TMP_DR_PATH_SED}/g" \
				-e "s/<WEBROOT>/${TMP_WR_PATH_SED}/g" \
				$LCFG_WS_SITES_PATH_AVAIL/$LCFG_WS_SITECONF_DEF_HTTP
	fi
	if [ -f $LCFG_WS_SITES_PATH_AVAIL/$LCFG_WS_SITECONF_DEF_HTTPS ]; then
		sed -i \
				-e "s/<DOCROOT>/${TMP_DR_PATH_SED}/g" \
				-e "s/<WEBROOT>/${TMP_WR_PATH_SED}/g" \
				$LCFG_WS_SITES_PATH_AVAIL/$LCFG_WS_SITECONF_DEF_HTTPS
	fi

	if [ -n "$CF_PHP_FPM_VERSION" ]; then
		sed -i \
				-e "s/<DOCROOT>/${TMP_WR_PATH_SED}/g" \
				/etc/php/${CF_PHP_FPM_VERSION}/fpm/pool.d/www.conf
	fi
	return 0
}

# ----------------------------------------------------------

# @return int EXITCODE
function _changeApacheServername() {
	# the FQDN should not contain slashes - but just to be safe...
	local TMP_FQDN="$(echo -n "$CF_PROJ_PRIMARY_FQDN" | sed -e 's/\//\\\//g')"
	if [ -f $LCFG_WS_SITES_PATH_AVAIL/$LCFG_WS_SITECONF_DEF_HTTP ]; then
		sed -i \
				-e "s/^#ServerName <PRIMARY_FQDN>$/ServerName ${TMP_FQDN}/g" \
				$LCFG_WS_SITES_PATH_AVAIL/$LCFG_WS_SITECONF_DEF_HTTP || return 1
	fi
	if [ -f $LCFG_WS_SITES_PATH_AVAIL/$LCFG_WS_SITECONF_DEF_HTTPS ]; then
		sed -i \
				-e "s/^#ServerName <PRIMARY_FQDN>$/ServerName ${TMP_FQDN}/g" \
				$LCFG_WS_SITES_PATH_AVAIL/$LCFG_WS_SITECONF_DEF_HTTPS || return 1
		#
		local TMP_FQDN_SSL="$CF_HTTPS_FQDN_DEFAULT"
		# the FQDN should not contain slashes - but just to be safe...
		TMP_FQDN_SSL="$(echo -n "$TMP_FQDN_SSL" | sed -e 's/\//\\\//g')"
		sed -i \
				-e "s/^#ServerName <PRIMARY_FQDN_SSL>$/ServerName ${TMP_FQDN_SSL}/g" \
				$LCFG_WS_SITES_PATH_AVAIL/$LCFG_WS_SITECONF_DEF_HTTPS || return 1
	fi
	return 0
}

# ----------------------------------------------------------

# @return int EXITCODE
function _changePhpFpmSettings() {
	if [ "$CF_PHPFPM_RUN_AS_WWWDATA" != "true" ]; then
		sed -i \
				-e "s/^user = .*$/user = wwwphpfpm/g" \
				-e "s/^group = .*$/group = wwwphpfpm/g" \
				/etc/php/${CF_PHP_FPM_VERSION}/fpm/pool.d/www.conf || return 1
	fi
	#
	local TMP_UTD_PATH_SED="$CF_PHPFPM_UPLOAD_TMP_DIR"
	echo -n "$TMP_UTD_PATH_SED" | grep -q -e "/$" || TMP_UTD_PATH_SED+="/"
	TMP_UTD_PATH_SED="$(echo -n "$TMP_UTD_PATH_SED" | sed -e 's/\//\\\//g')"
	sed -i \
			-e "s/<UPLOADTMPDIR>/${TMP_UTD_PATH_SED}/g" \
			/etc/php/${CF_PHP_FPM_VERSION}/fpm/pool.d/www.conf || return 1
	#
	if [ "$CF_PHPFPM_ENABLE_OPEN_BASEDIR" = "true" ]; then
		sed -i \
				-e "s/^;php_admin_value\[open_basedir\] = /php_admin_value[open_basedir] = /g" \
				/etc/php/${CF_PHP_FPM_VERSION}/fpm/pool.d/www.conf || return 1
	fi
	#
	local TMP_HE="on"
	[ "$CF_PHPFPM_HTML_ERRORS" != "true" ] && TMP_HE="off"
	sed -i \
			-e "s/^pm\.max_children = .*$/pm.max_children = ${CF_PHPFPM_PM_MAX_CHILDREN}/g" \
			-e "s/^pm\.start_servers = .*$/pm.start_servers = ${CF_PHPFPM_PM_START_SERVERS}/g" \
			-e "s/^pm\.min_spare_servers = .*$/pm.min_spare_servers = ${CF_PHPFPM_PM_MIN_SPARE_SERVERS}/g" \
			-e "s/^pm\.max_spare_servers = .*$/pm.max_spare_servers = ${CF_PHPFPM_PM_MAX_SPARE_SERVERS}/g" \
			-e "s/^php_admin_value\[upload_max_filesize\] = .*$/php_admin_value[upload_max_filesize] = ${CF_PHPFPM_UPLOAD_MAX_FILESIZE}/g" \
			-e "s/^php_admin_value\[post_max_size\] = .*$/php_admin_value[post_max_size] = ${CF_PHPFPM_POST_MAX_SIZE}/g" \
			-e "s/^php_admin_value\[memory_limit\] = .*$/php_admin_value[memory_limit] = ${CF_PHPFPM_MEMORY_LIMIT}/g" \
			-e "s/^php_admin_value\[max_execution_time\] = .*$/php_admin_value[max_execution_time] = ${CF_PHPFPM_MAX_EXECUTION_TIME}/g" \
			-e "s/^php_admin_value\[max_input_time\] = .*$/php_admin_value[max_input_time] = ${CF_PHPFPM_MAX_INPUT_TIME}/g" \
			-e "s/^php_admin_flag\[html_errors\] = .*$/php_admin_flag[html_errors] = ${TMP_HE}/g" \
			/etc/php/${CF_PHP_FPM_VERSION}/fpm/pool.d/www.conf
}

# ----------------------------------------------------------

# @param string $1 Filename
#
# @return int EXITCODE
function _changePhpTimezone_sub() {
	local TMP_FN="/etc/php/${CF_PHP_FPM_VERSION}/$1"

	[ ! -f "$TMP_FN" ] && return 0
	#
	grep -q "^;date.timezone =" "$TMP_FN"
	[ $? -ne 0 ] && return 0
	local TMP_TZ="$(echo -n "$CF_TIMEZONE" | sed -e 's/\//\\\//g')"
	sed -e "s/^;date.timezone =\$/date.timezone = '$TMP_TZ'/g" "$TMP_FN" > "${TMP_FN}.tmp" || return 1
	mv "${TMP_FN}.tmp" "$TMP_FN"
}

# @return int EXITCODE
function _changePhpTimezone() {
	_changePhpTimezone_sub "fpm/php.ini" || return 1
	_changePhpTimezone_sub "cli/php.ini"
}

# @return int EXITCODE
function _changeXdebugRemoteHost() {
	_log_def "Setting XDebug Remote Host to '$CF_XDEBUG_REMOTE_HOST'..."
	local TMP_FN="/etc/php/${CF_PHP_FPM_VERSION}/mods-available/xdebug.ini"
	local TMP_RH="$(echo -n "$CF_XDEBUG_REMOTE_HOST" | sed -e 's/\//\\\//g')"
	sed -e "s/^xdebug\.remote_host=.*/xdebug.remote_host=\"$TMP_RH\"/g" "$TMP_FN" > "${TMP_FN}.tmp" || return 1
	mv "${TMP_FN}.tmp" "$TMP_FN"
}

# ----------------------------------------------------------

# @return int EXITCODE
function _http_createDefaultSite() {
	cp $LCFG_WS_SITECONF_ORG_PATH/$LCFG_WS_SITECONF_DEF_HTTP \
			$LCFG_WS_SITES_PATH_AVAIL/
}

# ----------------------------------------------------------

# @return int EXITCODE
function _ssl_createDefaultSite() {
	cp $LCFG_WS_SITECONF_ORG_PATH/$LCFG_WS_SITECONF_DEF_HTTPS \
			$LCFG_WS_SITES_PATH_AVAIL/ || return 1
	#
	local TMP_FQDN_SSL="$CF_HTTPS_FQDN_DEFAULT"
	# the FQDN should not contain slashes - but just to be safe...
	TMP_FQDN_SSL="$(echo -n "$TMP_FQDN_SSL" | sed -e 's/\//\\\//g')"
	sed -i \
			-e "s/-<PRIMARY_FQDN_SSL>\./-${TMP_FQDN_SSL}\./g" \
			$LCFG_WS_SITES_PATH_AVAIL/$LCFG_WS_SITECONF_DEF_HTTPS || return 1
}

# @return void
function _ssl_setOwnerAndPerms() {
	[ -d "$1" ] && {
		chown $2:$3 "$1" && chmod "$4" "$1"
	}
	return 0
}

# @param string $1 Hostname
# @param string $2 Domain
# @param string $3 optional: "internal"
#
# @return int EXITCODE
function _ssl_generateCert() {
	local TMP_START_PATH_SUF=""
	[ "$3" = "internal" ] && TMP_START_PATH_SUF="-$3"
	local TMP_START_PRIVKEY_FN="${LCFG_SSL_PATH_HOST_KEYS}${TMP_START_PATH_SUF}/private-${1}.${2}.key"
	local TMP_START_PUB_CERT_FN="${LCFG_SSL_PATH_HOST_CERTS}${TMP_START_PATH_SUF}/client-${1}.${2}.crt"

	if [ -f "$TMP_START_PRIVKEY_FN" -a -f "$TMP_START_PUB_CERT_FN" ]; then
		_log_def "Not generating '$TMP_START_PRIVKEY_FN' and '$TMP_START_PUB_CERT_FN'. Files already exist."
	else
		_log_def "Generating '$TMP_START_PRIVKEY_FN' and '$TMP_START_PUB_CERT_FN'..."
		/root/sslgen.sh "${1}.${2}" $3 || return 1
	fi
	return 0
}

# @return int EXITCODE
function _ssl_generateCertDefaultSite() {
	local TMP_FQDN="${CF_PROJ_PRIMARY_FQDN:-default.localhost}"
	local TMP_HOSTN="$(echo -n "$TMP_FQDN" | cut -f1 -d.)"
	local TMP_DOM="$(echo -n "$TMP_FQDN" | cut -f2- -d.)"
	_ssl_generateCert "$TMP_HOSTN" "$TMP_DOM" "internal"
}

# @return int EXITCODE
function _ssl_generateCertOtherVhosts() {
	local TMP_CNT="$(find $LCFG_WS_SITES_PATH_ENAB/ -maxdepth 1 -type l -name "*-https${LCFG_WS_SITECONF_FEXT}" | grep -v "$LCFG_WS_SITECONF_DEF_HTTPS" | wc -l)"
	if [ "$TMP_CNT" = "0" ]; then
		_log_def "No further enabled virtual hosts with HTTPS found."
	else
		local TMP_FN
		for TMP_FN in `find $LCFG_WS_SITES_PATH_ENAB/ -maxdepth 1 -type l -name "*-https${LCFG_WS_SITECONF_FEXT}" | grep -v "$LCFG_WS_SITECONF_DEF_HTTPS"`; do
			_log_def "Generate Cert/Key for Virtual Host '$TMP_FN'..."
			local TMP_CRT_FN=""
			local TMP_KEY_FN=""
			if [ "$LVAR_WS_IS_APACHE" = "true" ]; then
				TMP_CRT_FN="$(grep '^[[:space:]]*SSLCertificateFile /.*$' "$TMP_FN" | awk '/client-.*\.crt/ { print $2 }')"
				TMP_KEY_FN="$(grep '^[[:space:]]*SSLCertificateKeyFile /.*$' "$TMP_FN" | awk '/private-.*\.key/ { print $2 }')"
			elif [ "$LVAR_WS_IS_NGINX" = "true" ]; then
				TMP_CRT_FN="$(grep '^[[:space:]]*ssl_certificate /.*$' "$TMP_FN" | awk '/client-.*\.crt/ { print $2 }' | tr -d \;)"
				TMP_KEY_FN="$(grep '^[[:space:]]*ssl_certificate_key /.*$' "$TMP_FN" | awk '/private-.*\.key/ { print $2 }' | tr -d \;)"
			fi
			[ -z "$TMP_CRT_FN" -o -z "$TMP_KEY_FN" ] && {
				_log_err "Error: could not determine Cert/Key filename. Aborting."
				return 1
			}
			#echo "  crt=$TMP_CRT_FN"
			#echo "  key=$TMP_KEY_FN"
			TMP_CRT_FQDN="$(basename "$TMP_CRT_FN")"
			TMP_CRT_FQDN="$(echo -n "$TMP_CRT_FQDN" | sed -e 's/^client-//' -e 's/\.crt$//')"
			TMP_KEY_FQDN="$(basename "$TMP_KEY_FN")"
			TMP_KEY_FQDN="$(echo -n "$TMP_KEY_FQDN" | sed -e 's/^private-//' -e 's/\.key$//')"
			#echo "  crt FQDN=$TMP_CRT_FQDN"
			#echo "  key FQDN=$TMP_KEY_FQDN"
			[ -z "$TMP_CRT_FQDN" -o -z "$TMP_KEY_FQDN" -o "$TMP_CRT_FQDN" != "$TMP_KEY_FQDN" ] && {
				_log_err "Error: FQDN not found in Cert/Key filenames. Aborting."
				return 1
			}

			if [ -f "$TMP_KEY_FN" -a -f "$TMP_CRT_FN" ]; then
				_log_def "Not generating '$TMP_KEY_FN' and '$TMP_CRT_FN'. Files already exist."
			else
				_log_def "Generating '$TMP_KEY_FN' and '$TMP_CRT_FN'..."
				/root/sslgen.sh "$TMP_CRT_FQDN" || return 1
			fi
		done
	fi
	return 0
}

# Change numeric ID of group 'ssl-cert' to user-supplied numeric ID
#
# @return int EXITCODE
function _ssl_createSslCertGroup() {
	getent group "ssl-cert" >/dev/null 2>&1 && groupdel "ssl-cert"

	_log_def "Setting numeric group ID of ssl-cert to ${CF_SSLCERT_GROUP_ID}..."
	groupadd -g ${CF_SSLCERT_GROUP_ID} "ssl-cert"
}

# ----------------------------------------------------------

if [ "$CF_ENABLE_HTTPS" = "true" ]; then
	_ssl_createSslCertGroup || {
		_log_err "Error: creating ssl-cert group with GID=${CF_SSLCERT_GROUP_ID} failed. Aborting."
		_sleepBeforeAbort
	}

	#
	_ssl_setOwnerAndPerms "$LCFG_SSL_PATH_HOST_CERTS" root root "755"
	_ssl_setOwnerAndPerms "$LCFG_SSL_PATH_HOST_KEYS" root ssl-cert "750"
	_ssl_setOwnerAndPerms "$LCFG_SSL_PATH_LETSENCRYPT_WEBROOT" root root "755"

	if [ "$CF_CREATE_DEFAULT_HTTPS_SITE" = "true" ]; then
		# create default HTTPS site
		_log_def "Create default HTTPS site..."
		_ssl_createDefaultSite || {
			_sleepBeforeAbort
		}

		# enable default HTTPS site
		if [ ! -h $LCFG_WS_SITES_PATH_ENAB/$LCFG_WS_SITECONF_DEF_HTTPS ]; then
			_log_def "Enable default HTTPS site..."
			a2ensite $LCFG_WS_SITECONF_DEF_HTTPS || {
				_sleepBeforeAbort
			}
		fi

		# generate SSL-Cert/Key for default virtual host
		if [ -h $LCFG_WS_SITES_PATH_ENAB/$LCFG_WS_SITECONF_DEF_HTTPS ]; then
			_ssl_generateCertDefaultSite || {
				_sleepBeforeAbort
			}
		fi
	fi

	# generate SSL-Cert/Key for all other virtual hosts
	_ssl_generateCertOtherVhosts || exit 1

	# enable Apache SSL module
	a2enmod ssl || {
		_sleepBeforeAbort
	}
else
	# disable default HTTPS site
	if [ -h $LCFG_WS_SITES_PATH_ENAB/$LCFG_WS_SITECONF_DEF_HTTPS ]; then
		_log_def "Disable default HTTPS site..."
		a2dissite $LCFG_WS_SITECONF_DEF_HTTPS || {
			_sleepBeforeAbort
		}
	fi
fi

if [ "$CF_ENABLE_HTTP" = "true" ]; then
	if [ "$CF_CREATE_DEFAULT_HTTP_SITE" = "true" ]; then
		# create default HTTP site
		_log_def "Create default HTTP site..."
		_http_createDefaultSite || {
			_sleepBeforeAbort
		}

		# enable default HTTP site
		if [ ! -h $LCFG_WS_SITES_PATH_ENAB/$LCFG_WS_SITECONF_DEF_HTTP ]; then
			_log_def "Enable default HTTP site..."
			a2ensite $LCFG_WS_SITECONF_DEF_HTTP || {
				_sleepBeforeAbort
			}
		fi
	fi
else
	# disable default HTTP site
	if [ -h $LCFG_WS_SITES_PATH_ENAB/$LCFG_WS_SITECONF_DEF_HTTP ]; then
		_log_def "Disable default HTTP site..."
		a2dissite $LCFG_WS_SITECONF_DEF_HTTP || {
			_sleepBeforeAbort
		}
	fi
fi

_log_def "createUserGroup 'www-data'..."
_createUserGroup "www-data" "${CF_WWWDATA_USER_ID}" "${CF_WWWDATA_GROUP_ID}" || {
	_sleepBeforeAbort
}

if [ -n "$CF_PHP_FPM_VERSION" ]; then
	if [ "$CF_PHPFPM_RUN_AS_WWWDATA" != "true" ]; then
		_log_def "createUserGroup 'wwwphpfpm'..."
		_createUserGroup "wwwphpfpm" "${CF_WWWFPM_USER_ID}" "${CF_WWWFPM_GROUP_ID}" "www-data" || {
			_sleepBeforeAbort
		}
		[ ! -d /home/wwwphpfpm ] && mkdir /home/wwwphpfpm
		chown wwwphpfpm:wwwphpfpm -R /home/wwwphpfpm
		chmod 750 /home/wwwphpfpm
	fi
	_log_def "createPhpFpmUploadDir..."
	_createPhpFpmUploadDir || {
		_log_err "Error: could not create PHP-FPM Upload dir. Aborting."
		_sleepBeforeAbort
	}
	_log_def "changePhpFpmSettings..."
	_changePhpFpmSettings || {
		_log_err "Error: could not change PHP-FPM settings. Aborting."
		_sleepBeforeAbort
	}
fi

if [ -n "$CF_WEBROOT" -a -d "$CF_WEBROOT" ]; then
	if [ -n "$CF_WEBROOT_SITE" -a ! -d "$CF_WEBROOT/$CF_WEBROOT_SITE" ]; then
		_log_def "mkdir '$CF_WEBROOT/$CF_WEBROOT_SITE'..."
		mkdir -p "$CF_WEBROOT/$CF_WEBROOT_SITE" || {
			_sleepBeforeAbort
		}
	fi
	if [ "$CF_IS_FOR_NEOS_CMS" = "true" ]; then
		if [ -n "$CF_WEBROOT_SITE" -a ! -d "$CF_WEBROOT/$CF_WEBROOT_SITE/Web" ]; then
			_log_def "mkdir '$CF_WEBROOT/$CF_WEBROOT_SITE/Web'..."
			mkdir "$CF_WEBROOT/$CF_WEBROOT_SITE/Web" || {
				_sleepBeforeAbort
			}
		fi
	fi
	if [ "$CF_SET_OWNER_AND_PERMS_WEBROOT" = "true" ]; then
		_log_def "setOwnerPermsWebroot..."
		_setOwnerPermsWebroot || {
			_log_err "Error: could not set owner/perms of webroot. Aborting."
			_sleepBeforeAbort
		}
	fi
fi

if [ -n "$CF_WEBROOT" -a -d "$CF_WEBROOT" -a \
		-n "$CF_WEBROOT_SITE" -a -d "$CF_WEBROOT/$CF_WEBROOT_SITE" ]; then
	_log_def "changeApacheWebroot..."
	_changeApacheWebroot || {
		_sleepBeforeAbort
	}
fi

if [ -n "$CF_PROJ_PRIMARY_FQDN" ]; then
	_log_def "changeApacheServername..."
	_changeApacheServername || {
		_sleepBeforeAbort
	}
fi

# ----------------------------------------------------------

if [ -n "$CF_LANG" ]; then
	_log_def "Updating locale with '$CF_LANG'..."
	export LANG=$CF_LANG
	export LANGUAGE=$CF_LANG
	export LC_ALL=$CF_LANG
	update-locale LANG=$CF_LANG || {
		_sleepBeforeAbort
	}
	update-locale LANGUAGE=$CF_LANG
	update-locale LC_ALL=$CF_LANG
	echo "export LANG=$CF_LANG" >> ~/.bashrc
	echo "export LANGUAGE=$CF_LANG" >> ~/.bashrc
	echo "export LC_ALL=$CF_LANG" >> ~/.bashrc
fi

if [ -n "$CF_TIMEZONE" ]; then
	[ ! -f "/usr/share/zoneinfo/$CF_TIMEZONE" ] && {
		_log_err "Error: could not find timezone file for '$CF_TIMEZONE'. Aborting."
		_sleepBeforeAbort
	}
	_log_def "Setting timezone to '$CF_TIMEZONE'..."
	export TZ=$CF_TIMEZONE
	ln -snf /usr/share/zoneinfo/$CF_TIMEZONE /etc/localtime
	echo $CF_TIMEZONE > /etc/timezone
	#
	_changePhpTimezone
fi

# ----------------------------------------------------------

if [ -n "$CF_PHP_FPM_VERSION" ] && \
		[ "$CF_PHP_FPM_VERSION" != "7.4" -o "$CF_CPUARCH_DEB_DIST" = "amd64" ]; then
	if [ -n "$CF_XDEBUG_REMOTE_HOST" ]; then
		_changeXdebugRemoteHost || {
			_sleepBeforeAbort
		}
	fi
	if [ "$CF_ENABLE_XDEBUG" = "true" ]; then
		_log_def "Enabling XDebug..."
		phpenmod xdebug
	fi
fi

# ----------------------------------------------------------

# for child docker images:
if [ -x /start-child.sh ]; then
	_log_def "Calling '/start-child.sh'..."
	/start-child.sh || {
		_sleepBeforeAbort
	}
fi

# ----------------------------------------------------------

if [ -n "$CF_PHP_FPM_VERSION" ]; then
	_log_def "Starting PHP-FPM..."
	service php$CF_PHP_FPM_VERSION-fpm start || {
		_sleepBeforeAbort
	}
fi

if [ "$CF_ENABLE_CRON" = "true" ]; then
	#mkdir -p /var/spool/cron/crontabs 2>/dev/null
	#chmod +t /var/spool/cron/crontabs
	#chown :crontab /var/spool/cron/crontabs
	#
	TMP_FCNT="$(find /var/spool/cron/crontabs -type f | wc -l)"
	if [ "$TMP_FCNT" != "0" ]; then
		_log_def "chown+chmod '/var/spool/cron/crontabs/*'..."
		for FN in /var/spool/cron/crontabs/*; do
			chown $(basename "$FN"):crontab "$FN"
			chmod 600 "$FN"
		done
	fi
	#
	_log_def "Starting cron..."
	service cron start || {
		_sleepBeforeAbort
	}
fi

_log_def "Starting apache..."
apachectl -D FOREGROUND
