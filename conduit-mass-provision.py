#!/usr/bin/env python3

##############################################################################
#
# Module:  conduit-mass-provision.py
#
# Function:
#   Provision a large number of Conduits from the command line.
#
# Copyright and License:
#   Copyright (C) 2021, MCCI Corporation. See accompanying LICENSE file
#
# Author:
#   Terry Moore, MCCI   February, 2021
#
##############################################################################

import argparse
import pipes
import sys

### return the program version
def GetVersion():
    return "v1.0.0"

### parse the command line to args.
def ParseCommandArgs():
    parser = argparse.ArgumentParser(description="Provision one or more Conduits or Conduit APs")
    parser.add_argument(
        "-v",
        dest="fVerbose",
        action="store_true",
        help="verbose output",
        default=False
        )
    parser.add_argument(
        "--version",
        dest="fVersion",
        action="store_true",
        help="print version and exit",
        default=False
        )
    parser.add_argument(
        "--debug", "-D",
        dest="fDebug",
        action="store_true",
        help="produce debug output",
        default=False
        )
    return parser.parse_args()

# make a directory

# process args and return status
def main():
    # parse the command line args
    args = ParseCommandArgs()

    if args.fVersion:
        print("conduit-mass-provision.py", GetVersion())
        return 0

    if args.fDebug:
        print("args:", args)

    return 0

# set the main routine
if __name__ == "__main__":
    # we're running as a script, process the command
    sys.exit(main())

### end of file ###