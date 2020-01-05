#!/bin/bash

# remdotfiles
#
# Usage: $0 [-f]
#
# Remove all files and directories beginning with a dot.
# E.g.: .DS_Store
#
#
# by TS, 2009

TMPFN="/tmp/$MYNAME-find$$.tmp"
find . -type f \( -name "._*" -o -name ".DS_Store" \) | sort > $TMPFN
find . -type d -name ".*" | sort >> $TMPFN

# open FileDescriptor for TMPFN
READFD=34
eval "exec ${READFD}<${TMPFN}"

while read -u $READFD FN; do
	[ "$FN" = "." ] && continue
	[ "$FN" = ".." ] && continue
	[ "$FN" = "./" ] && continue
	[ "$FN" = "../" ] && continue
	x_isFile=true
	x_fileIsDsStore=false
	[ -d "$FN" ] && x_isFile=false
	if [ "$1" != "-f" ]; then
		[ $x_isFile = true ] && x_fdStr="" || x_fdStr="dir "
		FNbase="$(basename "$FN")"
		if [ $x_isFile = true ]; then
			[ "$FNbase" = ".DS_Store" -o "$FNbase" = "._.DS_Store" -o \
				-n "$(echo -n "$FNbase" | grep -q "^._" && echo y)" ] && x_fileIsDsStore=true
		fi
		if [ $x_isFile = false -o $x_fileIsDsStore = false ]; then
			[ "$FNbase" = ".git" ] && {
				echo "  (ignoring '$FN')"
				continue
			}
			echo -n "Remove $x_fdStr  '$FN'  ? [ <y> | n ] "
			read -n1 KEY
			if [ "$KEY" = "n" ]; then
				echo  "  --> leaving it alone..."
				continue
			fi
		fi
	fi
	echo -n "  --> removing"
	if [ "$1" = "-f" -o $x_fileIsDsStore = true ]; then
		echo -n " '$FN'"
	fi
	echo "..."
	[ $x_isFile == true ] && x_par="" || x_par="-r "
	[ "$1" = "-f" ] && x_par="$x_par -f "
	rm $x_par "$FN"
done

# close FileDescriptor
eval "exec ${READFD}<&-"

rm $TMPFN
