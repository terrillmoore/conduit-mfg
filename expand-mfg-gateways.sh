#!/bin/bash

#
# Name: expand-mfg-gateways.sh
#
# Function:
#	Process a list of gateways, and expand it to an initial database.
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
	Prepare gateway database from list of gateways.

Usage:
	$USAGE

Switches:
	-h		displays help (this message), and exits.

	-v		talk about what we're doing.

	-D		operate in debug mode.

	-s		Scan only -- don't change gateways.

	-I {org}	Set organization ID to "org", default "$OPTORGID_DFLT"

	-O {ownername}	Set owner name to "ownername", default "$OPTOWNER_DFLT"

	-mi#		Reserve first # infrastructure gateways for MCCI stock.

	-mp#		Reserve first # personal gateways for MCCI stock.

	-ii#		Set the starting index of customer infrastructure
			gateways to #.

	-ip#		set the starting index of cusotmer personal gateways
			to #.

	-p {file}	Read the initial root password from arg. Default is to
			read from stdin. (Reading from stdin may be explicitly
			selected using "-p -").

	-r *		set the initial root username to arg.

	-u *		Set the username to use when connecting to the jumphost.

	-k {keyfile}	specify the public key to be used for logging into
			the gateways (at least initially). Default:
			$OPTPUBKEY_DEFAULT.

File format
	The input file is a tab-separated database, with a header line, and at least
	the following columns.

	\$1	The gateway type (Conduit 246L or Conduit AP).
	\$2	The IP address of the gateway on the mfg network.
	\$3	The mac address of the gateway

	Additional columns, if present are used; otherwise they're populated.

	\$4	Gateway name
	\$5	GatewayID
	\$6	OrgID
	\$7	Public Key
	\$8	User number on jumphost
	\$9	keep alive port
	\$10	EUI64 of LoRa MAC
	\$11	tunnel status (ok or NG)
.
}

function _setstart {
	case "$3" in
	p)	OPTSTART_PERSONAL[$2]="$4";;
	i)	OPTSTART_INFRA[$2]="$4";;
	\?)	_error "$1: key $3 invalid"; exit 1;;
	esac
}

#### argument scanning:  usage ####
USAGE="${PNAME} -[Dhv I* j* k* O* ii# ip# mi# mp# p* s u#] {inputDB} ..."

OPTDEBUG=0
OPTVERBOSE=0
declare -r OPTJHUSER_DEFAULT="$USER"
OPTJHUSER="$OPTJHUSER_DEFAULT"
declare -r OPTJHFQDN_DEFAULT="jumphost.ttni.tech"
OPTJHFQDN="$OPTJHFQDN_DEFAULT"
OPTORGID_DFLT="ttn-ithaca"
OPTORGID="$OPTORGID_DFLT"
OPTOWNER_DFLT="Tompkins County"
OPTOWNER="$OPTOWNER_DFLT"
OPTPASSWD="-"
OPTROOT="mtadm"
declare -r OPTPUBKEY_DEFAULT=~/.ssh/tmm-conduit.pub
OPTPUBKEY="${OPTPUBKEY_DEFAULT}"
declare -i OPTSCANONLY=0

# set up the arrays OPTSTART_INFRA and OPTSTART_PERSONAL
declare -A OPTSTART_INFRA
declare -A OPTSTART_PERSONAL

OPTSTART_INFRA[MCCI]=0
OPTSTART_PERSONAL[MCCI]=0
OPTSTART_INFRA[OWNER]=1
OPTSTART_PERSONAL[OWNER]=1

# scan args.
NEXTBOOL=1
while getopts Dnhi:I:j:k:m:O:p:r:su:v c
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
	n)	NEXTBOOL=-1;;
	I)	OPTORGID="$OPTARG";;
	i)	_setstart "$c" OWNER "${OPTARG:0:1}" "${OPTARG:1}";;
	j)	OPTJHFQDN="$OPTARG";;
	k)	OPTPUBKEY="$OPTARG"
		test -f "$OPTPUBKEY" || _error "-$c: can't read key file: $OPTARG"
		;;
	m)	_setstart "$c" MCCI "${OPTARG:0:1}" "${OPTARG:1}";;
	O)	OPTOWNER="$OPTARG";;
	p)	OPTPASSWD="$OPTARG";;
	r)	OPTROOT="$OPTARG";;
	s)	OPTSCANONLY=$NEXTBOOL;;
	u)	OPTJHUSER="$OPTARG";;
	v)	OPTVERBOSE=$NEXTBOOL;;
	\?)	echo "$USAGE"
		exit 1;;
	esac
done

#### get rid of scanned options ####
shift $((OPTIND - 1))

test $# -ne 0 || _error "must provide at least one argument"

### log some info ###
for i in MCCI OWNER ; do
	_debug "OPTSTART_INFRA[$i]:" "${OPTSTART_INFRA[$i]}"
	_debug "OPTSTART_PERSONAL[$i]:" "${OPTSTART_PERSONAL[$i]}"
done

### fetch the password
if [[ "$OPTPASSWD" = "-" ]]; then
	read -r -s -p "Conduit password: " OPTPASSWD || _error "Couldn't get password"
else
	PASSWD_FILE="$OPTPASSWD"
	read -r -s -p "Conduit password (from $PASSWD_FILE): " OPTPASSWD < "$PASSWD_FILE" || _error "Couln't get password from $PASSWD_FILE"
fi

### do the work ###
awk 	-v nMCCIinfra="${OPTSTART_INFRA[MCCI]}" \
	-v nMCCIpersonal="${OPTSTART_PERSONAL[MCCI]}" \
	-v iPersonal=${OPTSTART_PERSONAL[OWNER]} \
	-v iInfra=${OPTSTART_INFRA[OWNER]} \
	-v sORGID="$OPTORGID" \
	-v sORGNAME="$OPTOWNER" \
	-v sPASSWD="$OPTPASSWD" \
	-v sJhUser="$OPTJHUSER" \
	-v sJhFqdn="$OPTJHFQDN" \
	-v optScanOnly="$OPTSCANONLY" \
	-v sCREATE_JUMPHOST_USER="$PDIR/create-jumphost-user.sh" \
	-v optVerbose="$OPTVERBOSE" \
	-v sSETUP_GATEWAY_TUNNEL="$PDIR/setup-gateway-tunnel.sh" \
	-v sSETUP_PASSWD="$PDIR/setpass.sh" \
	-v sPUBKEY="${OPTPUBKEY}" \
	-v sMTADM="${OPTROOT}" \
    '
    BEGIN {
        nPersonal = 0;
        nInfra = 0;
        FS="\t";
        OFS="\t"
        if (sMCCIORGID == "") {
            sMCCIORGID = sORGID;
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
    }
    (NR == 1) {
        $iGatewayName = "GatewayName"
        $iGatewayID = "GatewayID"
	$iOrgID = "OrgID"
	$iPublicKey = "PublicKey"
	$iUserNum = "UserNum"
	$iKeepalive = "Keepalive"
	$iEUI64 = "EUI64"
	$iTunnel = "TunnelStatus"
    }
    (NR > 1) {
	# add the mac address
        mac = tolower($iMac);
        gsub(/:/, "-", mac);

	if ($iOrgID == "") {
		$iOrgID = tolower(sORGID "-gateways");
	}

	if ($iGatewayName == "") {
		if ($iType == "Conduit AP") {
			if (nPersonal < nMCCIpersonal) {
				$iGatewayName = "MCCI AP " mac;
				$iGatewayID = tolower(sMCCIORGID "-" mac);
			} else {
				$iGatewayName = sORGNAME " Personal #" iPersonal++
				$iGatewayID = tolower(sORGID "-" mac);
			}
			++nPersonal;
		} else {
			if (nInfra < nMCCIinfra) {
				$iGatewayName = "MCCI " mac;
				$iGatewayID = tolower(sMCCIORGID "-" mac);
			} else {
				$iGatewayName = sORGNAME " #" iInfra++
				$iGatewayID = tolower(sORGID "-" mac);
			}
			++nInfra;
		}
        }

	if ($iGatewayID != "") {
		$iGatewayID = tolower($iGatewayID)
	}

	# fetch the gateway public key
	if ($iPublicKey == "" || $iPublicKey == "-") {
		cmd = "sshpass -p" sPASSWD " ssh -o \"PubkeyAuthentication no\" -o \"CheckHostIP no\" -o \"StrictHostKeyChecking no\" " sMTADM "@" $2 " cat /etc/ssh/ssh_host_rsa_key.pub"
		cmdstat = cmd | getline sPublicKey;
		close(cmd);
		if (cmdstat <= 0) {
			printf("%s: can'\''t get key\n", $2) > "/dev/stderr";
			$iPublicKey = "-";
		} else {
			$iPublicKey = sPublicKey;
		}
	}

	# fetch the lora EUI64
	if ($iEUI64 == "") {
		cmd = "sshpass -p" sPASSWD " ssh -o \"PubkeyAuthentication no\" -o \"CheckHostIP no\" -o \"StrictHostKeyChecking no\" " sMTADM "@" $2 " mts-io-sysfs show lora/eui"
		cmdstat = cmd | getline sEUI64;
		close(cmd);
		if (cmdstat <= 0) {
			printf("%s: can'\''t get EUI64\n", $2) > "/dev/stderr";
		} else {
			gsub(/[\t ]/, "", sEUI64);
			$iEUI64 = tolower(sEUI64);
		}
	} else {
		$iEUI64 = tolower($iEUI64);
	}

	# create the gateway user on the jumphost
	if (optScanOnly == 0) {
		cmd = sCREATE_JUMPHOST_USER
		if (optVerbose > 1) {
			cmd = cmd " -v";
		}
		cmd = cmd " -k \"" $iPublicKey "\" -j \"" sJhFqdn "\" -u \"" sJhUser "\" " $iGatewayID " " $iOrgID
		if (optVerbose != 0) {
			printf("%s\n", cmd) > "/dev/stderr";
		}
		cmdstat = cmd | getline sResult;
		close(cmd);
		if (cmdstat <= 0) {
			printf("%s: can'\''t get UserNumber\n", $2) > "/dev/stderr";
		} else {
			split(sResult, tResult, " ");
			$iUserNum = tResult[1];
			$iKeepalive = tResult[2];
		}
	}

	# next, load up the tunnel to the jumphost on the gateway
	# printf("$iTunnel=%s $iUserNum=%s $iKeepalive=%s $iGatewayID=%s $iOrgID=%s\n",
	#	$iTunnel, $iUserNum, $iKeepalive, $iGatewayID, $iOrgID) > "/dev/stderr";

	if (optScanOnly == 0 && $iTunnel != "OK" &&
	    $iUserNum != "" && $iKeepalive != "" &&
	    $iGatewayID != "" && $iOrgID != "") {
		# to get a password, we'\''re going to need a script in /tmp to pass to ssh.
		sGetPassFile = "/tmp/setpass.sh"
		# create the rev ssh tunnel on the target
		sshpasspfx = "sshpass -p" sPASSWD " ";
		sshpfx = sshpasspfx "ssh -o \"PubkeyAuthentication no\" -o \"CheckHostIP no\" -o \"StrictHostKeyChecking no\" " sMTADM "@" $iIP " ";
		if (sMTADM != "root") {
			sshrootpfx = sshpfx "SUDO_ASKPASS=" sGetPassFile " MYPASSWD=\"" sPASSWD "\" sudo -A ";
		} else {
			sshrootpfx = sshpfx
		}
		scppfx = sshpasspfx "scp -o \"PubkeyAuthentication no\" -o \"CheckHostIP no\" -o \"StrictHostKeyChecking no\" ";

		cmd = ""
		cmd = cmd scppfx sSETUP_GATEWAY_TUNNEL " " sMTADM "@" $iIP ":/tmp/setup-gateway-tunnel && ";
		if (sMTADM != "root") {
			cmd = cmd scppfx sSETUP_PASSWD " " sMTADM "@" $iIP ":" sGetPassFile " && "
			cmd = cmd sshpfx "chmod +x " sGetPassFile " && "
		}
		cmd = cmd scppfx sPUBKEY " " sMTADM "@" $iIP ":/tmp/authorized_keys && ";
		cmd = cmd sshrootpfx sprintf("JUMPHOST=\"%s\" JUMPPORT=22 JUMPUID=%u KEEPALIVE=%u MYNAME=\"%s\" MYPUBKEY=/tmp/authorized_keys sh /tmp/setup-gateway-tunnel",
				sJhFqdn, $iUserNum, $iKeepalive, $iGatewayID);

		if (optVerbose != 0) {
			printf("%s\n", cmd) > "/dev/stderr";
		}

		cmdstat = cmd | getline sIgnore;
		close(cmd);
		if (cmdstat <= 0) {
			printf("%s: can'\''t setup tunnel: status %d\n", $2, cmdstat) > "/dev/stderr";
			$iTunnel = "NG"
		} else {
			$iTunnel = "OK"
		}
	}
    }
    {print}
    ' "$@"
