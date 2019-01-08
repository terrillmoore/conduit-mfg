#!/bin/bash

#
# Name: create-jumphost-user.sh
#
# Function:
#	Create a jumphost user for a gateway.
#
# Copyright Notice:
#	This file copyright (c) 2018 by:
#
#       	MCCI Corporation
#       	3520 Krums Corners Road
#       	Ithaca, NY 14850
#
#   	Refer to separate license file for granted license.
#
# Author:
#   	Terry Moore, MCCI Corporation
#

PNAME=$(basename "$0")

# this is part of the pattern so:
# shellcheck disable=2034
PDIR=$(dirname "$0")

# output to terminal, but only if verbose.
function _verbose {
	if [ "$OPTVERBOSE" -ne 0 ]; then
		echo "$PNAME:" "$@" 1>&2
	fi
}

# output to terminal, but only if debig.
function _debug {
	if [ "$OPTDEBUG" -ne 0 ]; then
		echo "$PNAME:" "$@" 1>&2
	fi
}

# fatal error
function _error {
	echo "$PNAME:" "$@" 1>&2
	exit 1
}

# produce the help message.
function _help {
	more 1>&2 <<.

Name:	$PNAME

Function:
	Create a jumphost user for a gateway, or query info.

Usage:
	$PNAME [switches] gwnuname gwgroup

	gwuname is the login name of the gateway. This user
	name must not already exist. 

	gwgroup is the login group of the gateway; it's only
	used when creating a new gateway. If the group doesn't
	exist, a new one will be created.

Switches:
	-h		displays help (this message), and exits.

	-v		talk about what we're doing.

	-D		operate in debug mode.

	-Q		query information.

	-j {jh-fqdn}	Fully-qualified domain of jumphost, default
			"$OPTJHFQDN_DEFAULT"

	-k {gw-pubkey}	Public key of gateway (ignored if -Q)

	-u {jh-user}	User name to use for logging into jumphost,
			default "$OPTJHUSER_DEFAULT"

	-U {uid}	User ID to use for the new group. This
			is only used when renaming gateways.
.
}

#### parameters, not tunable ####
declare -i FIRSTUID=20000
declare -i FIRSTKEEPALIVE=40000
declare -i JUMPPORT=22

#### argument scanning:  usage ####
USAGE="${PNAME} -[DhQv j* k* U* ] gw-uname [ gw-gname ]"

declare -i OPTDEBUG=0
declare -i OPTVERBOSE=0
declare -i OPTQUERY=0
declare -r OPTJHUSER_DEFAULT="$USER"
OPTJHUSER="$OPTJHUSER_DEFAULT"
declare -r OPTJHFQDN_DEFAULT="ec2-54-221-216-139.compute-1.amazonaws.com"
OPTJHFQDN="$OPTJHFQDN_DEFAULT"
declare -i OPTUID=0

# scan args.
NEXTBOOL=1
while getopts Dnhj:k:Qu:U:v c
do
	if [ $NEXTBOOL -eq -1 ]; then
		NEXTBOOL=0
	else
		NEXTBOOL=1
	fi

	if [ $OPTDEBUG -ne 0 ]; then
		echo "Scanning option -${c}" 1>&2
	fi

	case $c in
	D)	OPTDEBUG=$NEXTBOOL;;
	h)	_help
		exit 0
		;;
	v)	OPTVERBOSE=$NEXTBOOL;;
	n)	NEXTBOOL=-1;;

	j)	OPTJHFQDN="$OPTARG";;
	k)	OPTKEY="$OPTARG";;
	Q)	OPTQUERY=$NEXTBOOL;;
	u)	OPTJHUSER="$OPTARG";;
	U)	OPTUID="$OPTARG";;
	\?)	echo "$USAGE"
		exit 1;;
	esac
done

#### get rid of scanned options ####
shift	$((OPTIND - 1))

if [ $OPTQUERY -eq 0 ] && [ $# -ne 2 ]; then
	_error "Must specify gw uname and group: $USAGE"
elif [ $OPTQUERY -ne 0 ] && [ $# -ne 1 ]; then 
	_error "-Q allows only gw uname"
fi

JUMPADMIN="$OPTJHUSER"
JUMPHOST="$OPTJHFQDN"
MYNAME="$1"
MYGROUP="$2"

# check that we can connect to jumphost
_verbose "Check basic connectivity to $JUMPADMIN@$JUMPHOST"
ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" true ||
	_error "Can't connect to $JUMPHOST as $JUMPADMIN"

_verbose "Check sudo for $JUMPADMIN@$JUMPHOST"
ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" -T sudo true ||
	_error "Can't sudo on $JUMPHOST as $JUMPADMIN"

# create our user
declare -i FOUNDUSER=0
ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" \
	grep -q "^$MYNAME:" /etc/passwd && FOUNDUSER=1

if [ $OPTQUERY -ne 0 ]; then
	if [ $FOUNDUSER -eq 0 ]; then
		_error "Gateway user not found: '$MYNAME'"
	fi

	MYSSHKEY=$(
	    ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" \
		sudo head -1 /home/"$MYNAME"/.ssh/authorized_keys
	)
	MYPWENT=$(
	    ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" \
		grep "^$MYNAME:" /etc/passwd
	)
	_verbose "PWENT: '$MYPWENT'"
	_verbose "SSH-key: '$MYSSHKEY'"
	typeset -i MYUID=$(echo "$MYPWENT" | cut -d: -f 3)
	echo "Use these options when renaming this gateway:"
	echo "-U $MYUID -k '$MYSSHKEY'"
	exit 0
fi

declare -i FOUNDGROUP=0
ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" \
	grep -q "^$MYGROUP:" /etc/group && FOUNDGROUP=1

if [ $FOUNDGROUP -eq 0 ]; then
	_verbose "Creating group $MYGROUP"
	ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" -T \
		sudo groupadd "$MYGROUP" || \
			_error "groupadd ${MYGROUP} failed"
else
	_verbose "Group already exists: $MYGROUP"
fi

if [ $FOUNDUSER -eq 0 ]; then
    if [ "$OPTUID" -eq 0 ]; then
	_verbose "Creating $MYNAME"
	USEROPTS=
    else
	_verbose "Creating $MYNAME with userid $OPTUID"
	USEROPTS="--non-unique --uid $OPTUID"
    fi

# USEROPTS is deliberately not quoted
# shellcheck disable=2086
_debug ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" \
	sudo useradd --comment "$MYNAME" --password "*" \
		--gid "${MYGROUP}" \
		--no-user-group \
		--create-home \
		$USEROPTS \
		--key UID_MIN="${FIRSTUID}" "$MYNAME"

# USEROPTS is deliberately not quoted
# shellcheck disable=2086
ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" \
	sudo useradd --comment "$MYNAME" --password '\*' \
		--gid "${MYGROUP}" \
		--no-user-group \
		--create-home \
		$USEROPTS \
		--key UID_MIN="${FIRSTUID}" "$MYNAME" || \
			_error "useradd ${MYNAME} failed"
else
	_verbose "User already exists: $MYNAME"
fi

_debug "Get user ID"
JUMPUID=$(ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" \
		grep "^$MYNAME:" /etc/passwd |
		cut -d: -f3)
_verbose "User ID for $MYNAME is $JUMPUID"

# no benefit from rewriting at this time.
# shellcheck disable=2003
KEEPALIVE=$(expr '(' "$JUMPUID" - "$FIRSTUID" ')' '*' 2 + "$FIRSTKEEPALIVE")
_verbose "Keepalive port for $MYNAME is $KEEPALIVE"

# create ssh dir
_verbose "Creating .ssh dir for $MYNAME"
if ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" \
        sudo -u "$MYNAME" "sh -c '
		cd &&
		if [ ! -d .ssh ] ; then
			mkdir -m 700 .ssh || exit 1 ;
		fi'" ; then
	true
else
	_error "mkdir .ssh failed"
fi

# copy public key
_verbose "Create authorized_keys for $MYNAME"
echo "${OPTKEY}" | ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" \
        sudo "sh -c 'cat - >~${MYNAME}/.ssh/authorized_keys'" ||
		_error "can't create authorized_keys"

_verbose "Change ownership of authorized_keys"
ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" \
	sudo chown "$MYNAME" "~$MYNAME/.ssh/authorized_keys" || \
		_error "can't chown authorized_keys"

_verbose "Change permissions on authorized_keys"
ssh -p "$JUMPPORT" "$JUMPADMIN"@"$JUMPHOST" \
	sudo chmod 600 "~$MYNAME/.ssh/authorized_keys" || \
		_error "can't chmod authorized_keys"

# output the user id (port number)
printf "%s\t%s\n" "$JUMPUID" "$KEEPALIVE"

_verbose "Done!"
