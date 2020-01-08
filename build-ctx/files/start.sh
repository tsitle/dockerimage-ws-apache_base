#!/bin/bash

#
# by TS, May 2019
#

VAR_MYNAME="$(basename "$0")"

# ----------------------------------------------------------

export HOST_IP=$(/sbin/ip route|awk '/default/ { print $3 }')
echo "$HOST_IP dockerhost" >> /etc/hosts

CF_WWWDATA_USER_ID=${CF_WWWDATA_USER_ID:-33}
CF_WWWDATA_GROUP_ID=${CF_WWWDATA_GROUP_ID:-33}

CF_WWWFPM_USER_ID=${CF_WWWFPM_USER_ID:-1000}
CF_WWWFPM_GROUP_ID=${CF_WWWFPM_GROUP_ID:-1000}

# ----------------------------------------------------------

function _sleepBeforeAbort() {
	# to allow the user to see this message in 'docker logs -f CONTAINER' we wait before exiting
	echo "$VAR_MYNAME: (sleeping 5s before aborting)" >/dev/stderr
	local TMP_CNT=0
	while [ $TMP_CNT -lt 5 ]; do
		sleep 1
		echo "$VAR_MYNAME: (...)" >/dev/stderr
		TMP_CNT=$(( TMP_CNT + 1 ))
	done
	echo "$VAR_MYNAME: (aborting now)" >/dev/stderr
	exit 1
}

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
		echo "$VAR_MYNAME: Error: non-numeric User ID '$TMP_NID_U' supplied for '$1'. Aborting." >/dev/stderr
		return 1
	}
	echo -n "$TMP_NID_G" | grep -q -E "^[0-9]*$" || {
		echo "$VAR_MYNAME: Error: non-numeric Group ID '$TMP_NID_G' supplied '$1'. Aborting." >/dev/stderr
		return 1
	}
	[ ${#TMP_NID_U} -gt 5 ] && {
		echo "$VAR_MYNAME: Error: numeric User ID '$TMP_NID_U' for '$1' has more than five digits. Aborting." >/dev/stderr
		return 1
	}
	[ ${#TMP_NID_G} -gt 5 ] && {
		echo "$VAR_MYNAME: Error: numeric Group ID '$TMP_NID_G' for '$1' has more than five digits. Aborting." >/dev/stderr
		return 1
	}
	[ $TMP_NID_U -eq 0 ] && {
		echo "$VAR_MYNAME: Error: numeric User ID for '$1' may not be 0. Aborting." >/dev/stderr
		return 1
	}
	[ $TMP_NID_G -eq 0 ] && {
		echo "$VAR_MYNAME: Error: numeric Group ID for '$1' may not be 0. Aborting." >/dev/stderr
		return 1
	}

	local TMP_ADD_G="$4"
	if [ -n "$TMP_ADD_G" ]; then
		echo -n "$TMP_ADD_G" | LC_ALL=C grep -q -E "^([0-9a-z_,]|-)*$" || {
			echo "$VAR_MYNAME: Error: additional Group-Memberships '$TMP_ADD_G' container invalid characters. Aborting." >/dev/stderr
			return 1
		}
	fi

	_removeUserAndGroup "$1"

	getent passwd $TMP_NID_U >/dev/null 2>&1 && {
		echo "$VAR_MYNAME: Error: numeric User ID '$TMP_NID_U' already exists. Aborting." >/dev/stderr
		return 1
	}
	getent group $TMP_NID_G >/dev/null 2>&1 && {
		echo "$VAR_MYNAME: Error: numeric Group ID '$TMP_NID_G' already exists. Aborting." >/dev/stderr
		return 1
	}

	local TMP_ARG_ADD_GRPS=""
	[ -n "$TMP_ADD_G" ] && TMP_ARG_ADD_GRPS="-G $TMP_ADD_G"

	echo "$VAR_MYNAME: Setting numeric user/group ID of '$1' to ${TMP_NID_U}/${TMP_NID_G}..."
	groupadd -g ${TMP_NID_G} "$1" || {
		echo "$VAR_MYNAME: Error: could not create Group '$1'. Aborting." >/dev/stderr
		return 1
	}
	useradd -l -u ${TMP_NID_U} -g "$1" $TMP_ARG_ADD_GRPS -M -s /bin/false "$1" || {
		echo "$VAR_MYNAME: Error: could not create User '$1'. Aborting." >/dev/stderr
		return 1
	}
	return 0
}

# Create Upload directory for PHP-FPM
#
# @return void
function _createPhpFpmUploadDir() {
	local TMP_UPL_DIR="/var/www/upload_tmp_dir"
	[ -d "$TMP_UPL_DIR" ] || mkdir "$TMP_UPL_DIR"
	chown wwwphpfpm:wwwphpfpm "$TMP_UPL_DIR" || return 1
	chmod u=rwx,g=rwxs,o= "$TMP_UPL_DIR"
}

# ----------------------------------------------------------

# @return int EXITCODE
function _setOwnerPermsWebroot() {
	local TMP_WEB_USER="www-data"
	local TMP_WEB_GROUP="www-data"
	if [ -n "$CF_PHP_FPM_VERSION" ]; then
		TMP_WEB_USER="wwwphpfpm"
		TMP_WEB_GROUP="wwwphpfpm"
	fi
	local TMP_WEBR_SITE="$CF_WEBROOT"
	[ -n "$CF_WEBROOT_SITE" -a -d "$CF_WEBROOT/$CF_WEBROOT_SITE" ] && TMP_WEBR_SITE="$TMP_WEBR_SITE/$CF_WEBROOT_SITE"
	echo "$VAR_MYNAME: Chown'ing and chmod'ing $TMP_WEBR_SITE"
	echo "               - chmod u=rwx,g=rwx,o=rx '$TMP_WEBR_SITE'"
	chmod u=rwx,g=rwx,o=rx "$TMP_WEBR_SITE" || return 1
	chmod u=r,g=r,o=r "$TMP_WEBR_SITE" || return 1
	echo "               - find '$TMP_WEBR_SITE' -type d -exec chmod u=rwx,g=rwxs,o=rx"
	find "$TMP_WEBR_SITE" -type d -exec chmod u=rwx,g=rwxs,o=rx '{}' \; || return 1
	echo "               - find '$TMP_WEBR_SITE' -type f -exec chmod ug=rw,o=r"
	find "$TMP_WEBR_SITE" -type f -exec chmod ug=rw,o=r '{}' \; || return 1
	echo "               - chown $TMP_WEB_USER:$TMP_WEB_GROUP -R '$TMP_WEBR_SITE'"
	chown $TMP_WEB_USER:$TMP_WEB_GROUP -R "$TMP_WEBR_SITE" || return 1
	# for Neos CMS:
	[ -f "$TMP_WEBR_SITE/flow" ] && {
		echo "               - chmod ug+x '$TMP_WEBR_SITE/flow'"
		chmod ug+x "$TMP_WEBR_SITE/flow" || return 1
	}
	return 0
}

# ----------------------------------------------------------

# @return int EXITCODE
function _changeApacheWebroot() {
	echo "$VAR_MYNAME: Setting webroot to '$CF_WEBROOT/$CF_WEBROOT_SITE'..."
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

	sed -i \
			-e "s/<DOCROOT>/${TMP_DR_PATH_SED}/g" \
			-e "s/<WEBROOT>/${TMP_WR_PATH_SED}/g" \
			/etc/apache2/sites-available/000-default.conf
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
	sed -i \
			-e "s/^#ServerName <PRIMARY_FQDN>$/ServerName ${TMP_FQDN}/g" \
			/etc/apache2/sites-available/000-default.conf
}

# ----------------------------------------------------------

function _changePhpTimezone() {
	local TMP_FN="/etc/php/${CF_PHP_FPM_VERSION}/fpm/php.ini"

	[ ! -f "$TMP_FN" ] && return 0
	#
	grep -q "^;date.timezone =" "$TMP_FN"
	[ $? -ne 0 ] && return 0
	local TMP_TZ="$(echo -n "$CF_TIMEZONE" | sed -e 's/\//\\\//g')"
	sed -e "s/^;date.timezone =\$/date.timezone = '$TMP_TZ'/g" "$TMP_FN" > "${TMP_FN}.tmp"
	mv "${TMP_FN}.tmp" "$TMP_FN"
}

# ----------------------------------------------------------

echo "$VAR_MYNAME: createUserGroup 'www-data'..."
_createUserGroup "www-data" "${CF_WWWDATA_USER_ID}" "${CF_WWWDATA_GROUP_ID}" || {
	_sleepBeforeAbort
}

if [ -n "$CF_PHP_FPM_VERSION" ]; then
	echo "$VAR_MYNAME: createUserGroup 'wwwphpfpm'..."
	_createUserGroup "wwwphpfpm" "${CF_WWWFPM_USER_ID}" "${CF_WWWFPM_GROUP_ID}" "www-data" || {
		_sleepBeforeAbort
	}
	echo "$VAR_MYNAME: createPhpFpmUploadDir..."
	_createPhpFpmUploadDir || {
		echo "$VAR_MYNAME: Error: could not create PHP-FPM Upload dir. Aborting." >/dev/stderr
		_sleepBeforeAbort
	}
fi

if [ -n "$CF_WEBROOT" -a -d "$CF_WEBROOT" ]; then
	if [ -n "$CF_WEBROOT_SITE" -a ! -d "$CF_WEBROOT/$CF_WEBROOT_SITE" ]; then
		echo "$VAR_MYNAME: mkdir '$CF_WEBROOT/$CF_WEBROOT_SITE'..."
		mkdir -p "$CF_WEBROOT/$CF_WEBROOT_SITE" || {
			_sleepBeforeAbort
		}
	fi
	if [ "$CF_IS_FOR_NEOS_CMS" = "true" ]; then
		if [ -n "$CF_WEBROOT_SITE" -a ! -d "$CF_WEBROOT/$CF_WEBROOT_SITE/Web" ]; then
			echo "$VAR_MYNAME: mkdir '$CF_WEBROOT/$CF_WEBROOT_SITE/Web'..."
			mkdir "$CF_WEBROOT/$CF_WEBROOT_SITE/Web" || {
				_sleepBeforeAbort
			}
		fi
	fi
	if [ "${CF_SET_OWNER_AND_PERMS_WEBROOT:-false}" = "true" ]; then
		echo "$VAR_MYNAME: setOwnerPermsWebroot..."
		_setOwnerPermsWebroot || {
			echo "$VAR_MYNAME: Error: could not set owner/perms of webroot. Aborting." >/dev/stderr
			_sleepBeforeAbort
		}
	fi
fi

if [ -n "$CF_WEBROOT" -a -d "$CF_WEBROOT" -a \
		-n "$CF_WEBROOT_SITE" -a -d "$CF_WEBROOT/$CF_WEBROOT_SITE" ]; then
	echo "$VAR_MYNAME: changeApacheWebroot..."
	_changeApacheWebroot || {
		_sleepBeforeAbort
	}
fi

if [ -n "$CF_PROJ_PRIMARY_FQDN" ]; then
	echo "$VAR_MYNAME: changeApacheServername..."
	_changeApacheServername || {
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
		echo "$VAR_MYNAME: chown+chmod '/var/spool/cron/crontabs/*'..."
		for FN in /var/spool/cron/crontabs/*; do
			chown $(basename "$FN"):crontab "$FN"
			chmod 600 "$FN"
		done
	fi
	#
	echo "$VAR_MYNAME: Starting cron..."
	service cron start || {
		_sleepBeforeAbort
	}
fi

# ----------------------------------------------------------

if [ -n "$CF_LANG" ]; then
	echo "$VAR_MYNAME: Updating locale with '$CF_LANG'..."
	export LANG=$CF_LANG
	export LANGUAGE=$CF_LANG
	export LC_ALL=$CF_LANG
	update-locale LANG=$CF_LANG || {
		_sleepBeforeAbort
	}
fi

if [ -n "$CF_TIMEZONE" ]; then
	[ ! -f "/usr/share/zoneinfo/$CF_TIMEZONE" ] && {
		echo "$VAR_MYNAME: Could not find timezone file for '$CF_TIMEZONE'. Aborting." >/dev/stderr
		_sleepBeforeAbort
	}
	echo "$VAR_MYNAME: Setting timezone to '$CF_TIMEZONE'..."
	export TZ=$CF_TIMEZONE
	ln -snf /usr/share/zoneinfo/$CF_TIMEZONE /etc/localtime
	echo $CF_TIMEZONE > /etc/timezone
	#
	_changePhpTimezone
fi

# ----------------------------------------------------------

# for child docker images:
if [ -x /start-child.sh ]; then
	echo "$VAR_MYNAME: Calling '/start-child.sh'..."
	/start-child.sh || {
		_sleepBeforeAbort
	}
fi

# ----------------------------------------------------------

if [ -n "$CF_PHP_FPM_VERSION" ]; then
	echo "$VAR_MYNAME: Starting PHP-FPM..."
	service php$CF_PHP_FPM_VERSION-fpm start || {
		_sleepBeforeAbort
	}
fi

echo "$VAR_MYNAME: Starting apache..."
apachectl -D FOREGROUND
