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

PNAME=$(basename $0)
PDIR=$(dirname $0)

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
	The database file is multiple times by awk, so input must be
	a regular file.

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

# To upgrade to a specific version of mLinux, specify it here.
# It's best to do this when you are on the same network, or have
# serial console access to the gateway
# mlinux_version: 3.3.13

# Descriptive location of the gateway
description: '${GatewayName}'

# Location, use -1 for altitude if not known.
latitude: 0
longitude: 0
altitude: -1

#
# use the V3 file for SPI based forwarding.
#
forwarder_variant: mp
forwarder_version: 3.0.20-r1

# the authorized_keys (public) for getting to this host
host_authorized_keys:
 - 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDvnl9QPdC8KpZBchK7VaUAEX4XONfLks9VO1RL35XIGXDDyfg8eyk5cLy8k9oE1hFRYtdOdrnofUYHsr3GBAOzQdnrnh2ujMOCm0LP4G5w1UjjYRPFHzX2hnnllKnswHn3dbdopl6wLezZP79lv2YzlJ2e4BdSq56WmGb3iiTG21MOGuMBhovXMqwalaqG3ZuJg8PhYDW226lExotgkWKQzhjFQiG0t2OgqbGJB/Jhyq45YemZm65m2kjKW7BrDRXcvfelx2B6T69pjjT1xkyOR37nApMleAzSrmxOX3aIWzuKHwbUdr4WN6wVqYlMFrs1vFG9+XRf/A4JnbpCSl/njx9iZcamqk3G7CKQste/iOlfccxB6YR16riX6mU43Tq/mPUWKXHu6dT3aebZeJDgSU34GS+sh/vvmqS8p6OqGNpPUQDTupA9YGHZhFr5bdf/jiXsDWY0fIuHhBZMcOYytycPxLGdyw2yR1Gi5WIgTr5XDcXQNR5NjZcoC0oxBzHsY7i7VTL+yg1v1rcyOdE/Fqxzc6EswL4Uc8ODG31cwwo1Aow3yy/qxrJEuOAD19QCgvDvjP6EChzZxrJX3PAE1JFlFUZGmGnOpLkTiKVzStTqBTha6K5etfm0uWWqyTPoqdsGdPgkJ6etIPZMQ3S12VdO3Fr8CYO+D/N1k5V8Aw== tmm/Conduits'
 - 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCuqUXzdOA/uXjLs0581rz+pjtxfb6eoCXCIhsb8rAJK1jnbzCCxUx4bJaMGh/rWyD+19CMkKJJ3OTv0h+SEMvkeNcpXgR2bbS5qr5S20J0lXO9k15KheMz50u7fDLdW6qmFk2FY75bzJ6U9vrOxdt2xYXbtnJy0AEL+Db0SSUJY7bcYJpPmpHFaQ1sm3UNx7OmixxjoUcDcx/nOK/TDzh25uLXVYMItW6EINSjinoi9ZKk4lMd3JAL4wT9HW3qiTmcCP/YnETjDA/u/hW5MjQXAGFy9E8v40x+WTpu5XS0JOg3C4a0QsizJIwiYBDduxqDF5Z22sJxfCvDHU3F3RVSoXom6Rt9+AQ7xPBZuzSFFp/185/EsiM4p0NGKI/tk7KuEK00UrCHvkx7ghgw5Dwsd4je6Cmq4XijQtA7iYfDnIf8TQWdh6axQAzKWiBH0EYrJXJa8QZzy4X9IwHsNiLCL7SUQH8ONJME5B6yWp24tmjx2I1ulayxxgB6p5OYVlH8vLVo3lIrue5SrpL2iaotjxwI3yaX5Hy7JXRencw9R6nO2VEoN8U0DJOzZ5VdCW5CuvqHYP7esbsFnY3Jmyp3hlSpQRyIsNDHCEjU7KnMdXxIMdv/ghL4YO7tj+QV8CaFZvVPujAD6lic6HW4xUqyEkHAN3T2sRb8C/q/rhDcyw== ttni Conduit admin'
.
}

#### argument scanning:  usage ####
USAGE="${PNAME} -[DFhv -H* -I* -O*] {databasefile}"

declare -i OPTDEBUG=0
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
while getopts DFnhH:I:O:v c
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
shift	`expr $OPTIND - 1`

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

test -d ${OPTORGDIR}/inventory || _error "not a directory: ${OPTORGDIR}/inventory"
test -d ${OPTORGDIR}/inventory/host_vars || _error "not a directory: ${OPTORGDIR}/inventory/host_vars"

HOSTFILE=${OPTORGDIR}/inventory/${OPTHOSTFILE}

_getgateways "$@" | while IFS=$'\t' read GatewayID UserNum Keepalive GatewayName ; do
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

if [ X"${OPTHOSTFILE}" != X -a -f "${HOSTFILE}" ]; then
	if [ $OPTOVERWRITE -eq 0 ]; then
		_error "File exists: $HOSTFILE"
	fi
fi

_getgateways "$@" | while IFS=$'\t' read GatewayID UserNum Keepalive GatewayName ; do
	OUTFILE=${OPTORGDIR}/inventory/host_vars/${GatewayID}.yml
	_verbose "$OUTFILE: $GatewayName"
	_emit_template | \
	sed \
		-e 's/${GatewayID}/'"${GatewayID}"'/g' \
		-e 's/${UserNum}/'"${UserNum}"'/g' \
		-e 's/${Keepalive}/'"${Keepalive}"'/g' \
		-e 's/${GatewayName}/'"${GatewayName}"'/g' \
		> ${OUTFILE}		    
	done

if [ X"${OPTHOSTFILE}" != X ]; then
	{
	echo "[new]" 

	_getgateways "$@" | while >>${HOSTFILE} IFS=$'\t' read GatewayID UserNum Keepalive GatewayName ; do
		echo "${GatewayID}.yml"
    	done
	} >> "${HOSTFILE}"
fi
