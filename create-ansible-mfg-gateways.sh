#!/bin/bash

#
# Name: create-ansible-mfg-gateways.sh
#
# Function:
#	Process a list of gateways, and generate the ansible
#	files.
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
	Generate ansible files from gateway database

Usage:
	$USAGE

Switches:
	-h		displays help (this message), and exits.

	-v		talk about what we're doing.

	-D		operate in debug mode.

	-F		overwrite files even if they already exist.

	-I {awkpat}	Include only gateways with IDs matching awkpat; default
			is to include all gateways.

	-O {orgdir}	Set output directory; default is ${OPTORGDIR_DEFAULT}.
			Files are created as
				{orgdir}/inventory/host_vars/{gwid}.yml

	-H {hostfile}	Create hostfile fragment at
				{orgdir}/inventory/{hostfile}
			Section will be "[new]".
			Default is ${OPTHOSTFILE_DEFAULT}.

Notes:
	The database file is read multiple times by awk, so input must be
	a regular file. The gateways database is as created by
	expand-mfg-gateways.sh, also in this directory.

	Therefore, this script should be run after expand-mfg-gateways.sh.

.
}

#### emit the template yml file
function _emit_template {
	cat <<'.'
---
#
# Organizational-Params
#	GROUP=conduits.production

# Hostname.  Start with ttn-ORG
hostname: ${GatewayID}

# Define this to use an ssh tunnel.  Leave undefined or set to '0' to
# disable ssh tunnel.
ssh_tunnel_remote_port: ${UserNum}
ssh_tunnel_keepalive_base_port: ${Keepalive}
ssh_tunnel_local_port: 22	# used by gateway

# Actual address or hostname of the gateway.  This can be a hostname
# or IP address.
## ansible_ssh_common_args: normally use the default from conduits.yml
ansible_host: localhost
ansible_port: "{{ ssh_tunnel_remote_port }}"

ansible_user: root

# Uncomment the following to force network configuration to DHCP (this
# is the default config )
eth0_type: dhcp

# Uncomment and set the following info to set a static address
#eth0_type: static
#eth0_address: 10.0.0.51
#eth0_netmask: 255.255.255.0
#eth0_gateway: 10.0.0.1
# By default we'll configure google nameservers, if you want to
# specify, use:
#static_domain:   example.com
#static_nameservers:
#  - 192.168.1.4
#  - 192.168.1.5

# To configure wireless the following setup is required.  Wireless
# LANs usually use DHCP, but you can provide a static address in the
# same format as for an Ethernet interface.  Make sure that the
# wireless interface you have is supported by mLinux.
#eth0_type: manual
#wlan0_type: dhcp
# Wireless keys should not be stored here, but in a vault in this format
# For WPA-PSK and WPA-PSK2:
#wireless_keys: { ssid: 'MYNETWORKNAME', psk: 'ASecretPhrase' }
# For (very insecure) WEP and plain text
#wireless_keys: { ssid: 'MYNETWORKNAME', psk: 'TotallyInsecure', key_mgmt: 'NONE' }

# Descriptive location of the gateway
description: '${GatewayName}'

# Location, use -1 for altitude if not known.
latitude: 0
longitude: 0
altitude: -1

# Gateway owner (for v3): must be current user, or an organization for
# which the current user has access rights
# gateway_owner: "username" or "--organization-id orgid"

# the complete list of collaborators including the owner
gateway_collaborators:
  # - { username: jchonig, rights: [ gateway:status, gateway:delete ] }
  - { username: jchonig }
  - { username: terrillmoore }
  - { username: "cvb-mcci" }
  - { username: sjpark }
  # - { organization: OWNER from above }

# add the owner's or local admin's SSH public key here.
#authorized_keys:
#  - ''
.
}

#### argument scanning:  usage ####
USAGE="${PNAME} -[dDFhv -H* -I* -O*] {databasefile}"

declare -i OPTDEBUG=0
declare -i OPTDRYRUN=0
declare -i OPTVERBOSE=0
declare -r OPTINCLUDEPATTERN_DEFAULT='.*'
OPTINCLUDEPATTERN="${OPTINCLUDEPATTERN_DEFAULT}"
declare -r OPTORGDIR_DEFAULT='.'
OPTORGDIR="${OPTORGDIR_DEFAULT}"	# not specified: use current dir
declare -i OPTOVERWRITE=0

declare -r OPTHOSTFILE_DEFAULT=hosts_new
OPTHOSTFILE="${OPTHOSTFILE_DEFAULT}"

# scan args.
NEXTBOOL=1
while getopts dDFnhH:I:O:v c
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
	d)	OPTDRYRUN=$NEXTBOOL;;
	D)	OPTDEBUG=$NEXTBOOL;;
	F)	OPTOVERWRITE=$NEXTBOOL;;
	h)	_help
		exit 0
		;;
	n)	NEXTBOOL=-1;;
	H)	OPTHOSTFILE="$OPTARG";;
	I)	OPTINCLUDEPATTERN="$OPTARG";;
	O)	OPTORGDIR="$OPTARG"
		test -d "${OPTORGDIR}" || _error "-$c: not a directory: ${OPTORGDIR}"
		;;
	v)	OPTVERBOSE=$NEXTBOOL;;
	\?)	echo "$USAGE"
		exit 1;;
	esac
done

#### get rid of scanned options ####
shift	$((OPTIND - 1))

### do the work ###
function _getgateways {
awk 	-v optVerbose="$OPTVERBOSE" \
	-v sINCLUDE_PATTERN="${OPTINCLUDEPATTERN}" \
    '
    BEGIN {
        FS="\t";
        OFS="\t"
	iType = 1
	iIP = 2
	iMac = 3
	iGatewayName = 4
	iGatewayID = 5
	iOrgID = 6
	iPublicKey = 7
	iUserNum = 8
	iKeepalive = 9
	iEUI64 = 10
	iTunnel = 11
    }
    (NR == 1) {
	next;
    }
    (NR > 1) {
	# add the mac address
        mac = tolower($iMac);
        gsub(/:/, "-", mac);

	if ($iGatewayID ~ sINCLUDE_PATTERN) {
		printf("%s\t%u\t%u\t%s\n", $iGatewayID, $iUserNum, $iKeepalive, $iGatewayName);
	}
    }
    ' "$@"
 }

test -d "${OPTORGDIR}"/inventory || _error "not a directory: ${OPTORGDIR}/inventory"
test -d "${OPTORGDIR}"/inventory/host_vars || _error "not a directory: ${OPTORGDIR}/inventory/host_vars"

HOSTFILE=${OPTORGDIR}/inventory/${OPTHOSTFILE}

_getgateways "$@" | while IFS=$'\t' read -r GatewayID UserNum Keepalive GatewayName ; do
	_debug "GatewayID='${GatewayID}'"
	_debug "UserNum='${UserNum}'"
	_debug "Keepalive='${Keepalive}'"
	_debug "GatewayName='${GatewayName}'"
	OUTFILE=${OPTORGDIR}/inventory/host_vars/${GatewayID}.yml
	if [ -f "${OUTFILE}" ]; then
		if [ $OPTOVERWRITE -eq 0 ]; then
			_error "File exists: $OUTFILE"
		fi
	fi
done || exit $?

if [ X"${OPTHOSTFILE}" != X ] && [ -f "${HOSTFILE}" ]; then
	if [ $OPTOVERWRITE -eq 0 ]; then
		_error "File exists: $HOSTFILE"
	fi
fi

_getgateways "$@" | while IFS=$'\t' read -r GatewayID UserNum Keepalive GatewayName ; do
	OUTFILE=${OPTORGDIR}/inventory/host_vars/${GatewayID}.yml
	_verbose "$OUTFILE: $GatewayName"

	# we're deliberately expanding parameters so...
	# shellcheck disable=2016
	if [ $OPTDRYRUN -eq 0 ]; then
		_emit_template | \
		sed \
			-e 's/${GatewayID}/'"${GatewayID}"'/g' \
			-e 's/${UserNum}/'"${UserNum}"'/g' \
			-e 's/${Keepalive}/'"${Keepalive}"'/g' \
			-e 's/${GatewayName}/'"${GatewayName}"'/g' \
			> "${OUTFILE}"
	else
		echo "Would write gateway file: ${OUTFILE}"
	fi
done

if [ X"${OPTHOSTFILE}" != X ]; then
  if [ $OPTDRYRUN -eq 0 ]; then
	{
	printf "\n# move these to the test section above\n"
	printf "[test]\n"

	_getgateways "$@" | while >>"${HOSTFILE}" IFS=$'\t' read -r GatewayID UserNum Keepalive GatewayName ; do
		printf "%s\t#%s\n" "${GatewayID}" "${GatewayName}"
    	done
	} >> "${HOSTFILE}"
   else
	echo "Would write host file: ${HOSTFILE}"
   fi
fi
