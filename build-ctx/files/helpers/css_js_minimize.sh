#!/bin/bash

#
# by TS, 2016
#

# @param string $1 Path
# @param int $2 Recursion level
#
# @return string Absolute path
function realpath_osx() {
	local TMP_RP_OSX_RES=
	[[ $1 = /* ]] && TMP_RP_OSX_RES="$1" || TMP_RP_OSX_RES="$PWD/${1#./}"

	if [ -h "$TMP_RP_OSX_RES" ]; then
		TMP_RP_OSX_RES="$(readlink "$TMP_RP_OSX_RES")"
		# possible infinite loop...
		local TMP_RP_OSX_RECLEV=$2
		[ -z "$TMP_RP_OSX_RECLEV" ] && TMP_RP_OSX_RECLEV=0
		TMP_RP_OSX_RECLEV=$(( TMP_RP_OSX_RECLEV + 1 ))
		if [ $TMP_RP_OSX_RECLEV -gt 20 ]; then
			# too much recursion
			TMP_RP_OSX_RES="--error--"
		else
			TMP_RP_OSX_RES="$(realpath_osx "$TMP_RP_OSX_RES" $TMP_RP_OSX_RECLEV)"
		fi
	fi
	echo "$TMP_RP_OSX_RES"
}

# @param string $1 Path
#
# @return string Absolute path
function realpath_poly() {
	case "$OSTYPE" in
		linux*) realpath "$1" ;;
		darwin*) realpath_osx "$1" ;;
		*) echo "$VAR_MYNAME: Error: Unknown OSTYPE '$OSTYPE'" >/dev/stderr; echo -n "$1" ;;
	esac
}

VAR_MYNAME="$(basename "$0")"
VAR_MYDIR="$(realpath_poly "$0")"
VAR_MYDIR="$(dirname "$VAR_MYDIR")"

# ----------------------------------------------------------

if [ $# -eq 1 ]; then
	echo "$1" | grep -q "\.css$"
	RES_CSS=$?
	RES_JS=1
	if [ $RES_CSS -eq 0 ]; then
		#echo CSS
		java -jar "$VAR_MYDIR/"yuicompressor-2.4.8.jar -o '.css$:-min.css' $@
	else
		echo "$1" | grep -q "\.js$"
		RES_JS=$?
	fi
	if [ $RES_JS -eq 0 ]; then
		#echo JS
		java -jar "$VAR_MYDIR/"yuicompressor-2.4.8.jar -o '.js$:-min.js' $@
	elif [ $RES_CSS -ne 0 -a $RES_JS -ne 0 ]; then
		echo None
		java -jar "$VAR_MYDIR/"yuicompressor-2.4.8.jar $@
	fi
elif [ $# -eq 3 -a "$1" == "-o" ]; then
	echo "Usage: $VAR_MYNAME FILEN [lots_of_arguments_for_yuicompressor]" >/dev/stderr
	exit 1
else
	java -jar "$VAR_MYDIR/"yuicompressor-2.4.8.jar $@
fi
