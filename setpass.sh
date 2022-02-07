#!/bin/sh

# safety check
if [ ! -e /etc/mlinux-version ]; then
   echo "Not running on mLinux" >&2
   exit 1
fi

function _error {
	echo "$@" 1>&2
	exit 1
}

echo $MYPASSWD
