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

PNAME=$(basename $0)
PPATH=$(dirname $0)

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

	-I {org}	Set organization ID to "org", default "$OPTORGID_DFLT"

	-O {ownername}	Set owner name to "ownername", default "$OPTOWNER_DFLT"

	-mi #		Reserve first # infrastructure gateways for MCCI stock.

	-mp #		Reserve first # personal gateways for MCCI stock.

	-ii #		Set the starting index of customer infrastructure
			gateways to #.

	-ip #		set the starting index of cusotmer personal gateways
			to #.

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
USAGE="${PNAME} -[Dhv I* O* ii# ip# mi# mp#]"

OPTDEBUG=0
OPTVERBOSE=0
OPTORGID_DFLT="ttn-ithaca"
OPTORGID="$OPTORGID_DFLT"
OPTOWNER_DFLT="Tompkins County"
OPTOWNER="$OPTOWNER_DFLT"

declare -A OPTSTART_INFRA
declare -A OPTSTART_PERSONAL

OPTSTART_INFRA[MCCI]=0
OPTSTART_PERSONAL[MCCI]=0
OPTSTART_INFRA[OWNER]=1
OPTSTART_PERSONAL[OWNER]=1

NEXTBOOL=1
while getopts Dnhi:I:m:O:v c
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
	i)	_setstart $c OWNER "${OPTARG:0:1}" "${OPTARG:1}";;
	m)	_setstart $c MCCI "${OPTARG:0:1}" "${OPTARG:1}";;
	O)	OPTOWNER="$OPTARG";;
	v)	OPTVERBOSE=$NEXTBOOL;;
	\?)	echo "$USAGE"
		exit 1;;
	esac
done

#### get rid of scanned options ####
shift	`expr $OPTIND - 1`

### log some info ###
for i in MCCI OWNER ; do
	_debug "OPTSTART_INFRA[$i]:" "${OPTSTART_INFRA[$i]}"
	_debug "OPTSTART_PERSONAL[$i]:" "${OPTSTART_PERSONAL[$i]}"
done

### do the work ###
awk 	-v nMCCIinfra="${OPTSTART_INFRA[MCCI]}" \
	-v nMCCIpersonal="${OPTSTART_PERSONAL[MCCI]}" \
	-v iPersonal=${OPTSTART_INFRA[OWNER]} \
	-v iInfra=${OPTSTART_INFRA[OWNER]} \
	-v sORGID="$OPTORGID" \
	-v sORGNAME="$OPTOWNER" '
    BEGIN { 
        nPersonal = 0;
        nInfra = 0;
        FS="\t"; 
        OFS="\t" 
        if (sMCCIORGID == "") {
            sMCCIORGID = sORGID;
        }
    }
    (NR == 1) {
        $4 = "Gateway Name"
        $5 = "Gateway ID"
    }
    (NR > 1) { 
        mac = $3
        gsub(/:/, "-", mac); 
        if ($1 == "Conduit AP") {
            if (nPersonal < nMCCIpersonal) {
                $4 = "MCCI AP " mac;
                $5 = sMCCIORGID "-" mac;
            } else {
                $4 = sORGNAME " Personal #" iPersonal++
                $5 = sORGID "-" mac;
            }
            ++nPersonal; 
        } else {
            if (nInfra < nMCCIinfra) {
                $4 = "MCCI " mac;
                $5 = sMCCIORGID "-" mac;
            } else {
                $4 = sORGNAME " #" iInfra++
                $5 = sORGID "-" mac;
            }
            ++nInfra;
        }
    }
    {print}
    ' "$@"
