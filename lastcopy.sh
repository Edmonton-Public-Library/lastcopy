#!/bin/bash
###############################################################################
#
# Bash shell script for project lastcopy
# 
#    Copyright (C) 2022  Andrew Nisbet, Edmonton Public Library
# The Edmonton Public Library respectfully acknowledges that we sit on
# Treaty 6 territory, traditional lands of First Nations and Metis people.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.
#
###############################################################################
# 
# Goal make a list of all the cat ckeys, holds, and circulatable copies.
#
# Locations that are not circulatable are as follows. 
# UNKNOWN, MISSING, LOST, DISCARD, LOST-PAID, LONGOVRDUE,
# CANC_ORDER, INCOMPLETE, DAMAGE, BARCGRAVE, NON-ORDER,
# LOST-ASSUM, LOST-CLAIM, STOLEN, NOF, ILL
#
# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
#######################################################################
# ***           Edit these to suit your environment               *** #
. ~/.bashrc
#######################################################################
APP=$(basename -s .sh $0)
VERSION="1.00.02"
WORKING_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/LastCopy
# WORKING_DIR=/software/EDPL/Unicorn/EPLwork/anisbet/Discards/Test
TMP_DIR=/tmp
LOG=$WORKING_DIR/${APP}.log
ALT_LOG=/dev/null
LAST_COPY_LIST=$WORKING_DIR/${APP}.lst
# Used as a regex with pipe.pl
NON_CIRC_LOCATIONS='UNKNOWN|MISSING|LOST|DISCARD|LOST-PAID|LONGOVRDUE|CANC_ORDER|INCOMPLETE|DAMAGE|BARCGRAVE|NON-ORDER|LOST-ASSUM|LOST-CLAIM|STOLEN|NOF|ILL'
DEBUG=false
CIRC_COPIES=1
####### Functions ########
# Display usage message.
# param:  none
# return: none
usage()
{
    cat << EOFU!
Usage: $0 [-option]
 Creates a list of catalog keys, hold count, and visible copy counts
 in pipe-delimited format.
   ckey|title holds|circulatable copy count

 -c, --circ_copies=<integer> Sets the upper bound of circulate-able
   copies a title must have to make it to the 'last copy' list.
   Default is $CIRC_COPIES or less, which is usually fine.
 -d, --debug turn on debug logging.
 -h, --help: display usage message and exit.
 -l, --log=<path>: Appends logging to another log file.
 -v, --version: display application version and exit.
 -V, --VARS: Show variables used.
 -x, --xhelp: display usage message and exit.

EOFU!
	exit 1
}
# Logs messages to STDOUT and $LOG file.
# param:  Message to put in the file.
# param:  (Optional) name of a operation that called this function.
logit()
{
    local message="$1"
    local time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$time] $message" | tee -a $LOG -a "$ALT_LOG"
}
# Logs messages as an error and exits with status code '1'.
logerr()
{
    local message="${1} exiting!"
    local time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$time] **error: $message" | tee -a $LOG -a "$ALT_LOG"
    exit 1
}
# Displays variables.
show_vars()
{
    logit "\$APP=$0"
    logit "\$VERSION=$VERSION"
    logit "\$WORKING_DIR=$WORKING_DIR"
    logit "\$TMP_DIR=$TMP_DIR"
    logit "\$LOG=$LOG"
    logit "\$ALT_LOG=$ALT_LOG"
    logit "\$LAST_COPY_LIST=$LAST_COPY_LIST"
    logit "\$NON_CIRC_LOCATIONS=$NON_CIRC_LOCATIONS"
    logit "\$DEBUG=$DEBUG"
    logit "\$CIRC_COPIES=$CIRC_COPIES"
}
# Finds titles with last, or near to last copies in circulation.
find_last_copies()
{
    local allActiveHoldCKeys=$TMP_DIR/${APP}_all_active_holds_ckey.lst
    local allAHCItemLocations=$TMP_DIR/${APP}_all_active_holds_items_loc.lst
    local allVisibleItems=$TMP_DIR/${APP}_all_visible_items.lst
    local visibleItemCount=$TMP_DIR/${APP}_visible_item_count.lst
    local allCKeyHoldCountVisibleCopyCount=$TMP_DIR/${APP}_all_ckey_hold_count_visible_copy_count.lst
    # Objective: Find the count of active holds on each title.
    # Method: Select all the active holds, output their cat keys, dedup outputting the count and put the count on the end of each line.
    # Example: 1012345|5
    logit "selecting active holds"
    selhold -jACTIVE -oC 2>/dev/null | pipe.pl -dc0 -A -P | pipe.pl -o reverse >$allActiveHoldCKeys
    [ -s "$allActiveHoldCKeys" ] || logerr "no active holds found."
    # Objective: Given the list of cat keys with holds, find the locations of the items.
    # Method: Pipe cat keys into selitem outputting the cat key (barcode used for checking only) and location.
    # Example: 
    # 1000044|31221116612420  |DISCARD|
    # 1000044|31221116612396  |INTRANSIT|
    # 1000056|31221101053291  |HOLDS|
    logit "selecting items on titles with active holds"
    cat $allActiveHoldCKeys | selitem -iC -oCBm 2>/dev/null >$allAHCItemLocations
    [ -s "$allAHCItemLocations" ] || logerr "no items found."
    # Objective: Make a new list of items with only non-shadowed locations.
    # Method: Pipe the items and exclude hidden non-circulatable locations and save the list.
    # Example:
    # 1000044|31221116612396  |INTRANSIT|
    # 1000056|31221101053291  |HOLDS|
    [ "$DEBUG" == true ] && logit "removing items with non-circ locations."
    cat $allAHCItemLocations | pipe.pl -Gc2:"($NON_CIRC_LOCATIONS)"  >$allVisibleItems
    [ -s "$allVisibleItems" ] || logit "no visible items found."
    # Objective: Find all the cat ckeys and a count of circulatable items.
    # Mehod: De-duplicate all circulateable cat keys and add the count of duplicates to the end of each line.
    # Example:
    # 1000044|1
    # 1000056|1
    # 1000084|3
    [ "$DEBUG" == true ] && logit "computing visible copy count for titles."
    cat $allVisibleItems | pipe.pl -dc0 -A -P | pipe.pl -o c1,c0 >$visibleItemCount
    # Objective: Match ckeys with holds with ckeys with visible copies.
    # Method: pipe all the cat keys with holds, merge with the list of visible item counts, and if a cat key with holds
    #  matches a cat key with visible copies, add the visible copy count, otherwise add a zero (0).
    [ "$DEBUG" == true ] && logit "merging hold and visible copy lists."
    cat $allActiveHoldCKeys | pipe.pl -0 $visibleItemCount -M c0:c0?c1.0 >$allCKeyHoldCountVisibleCopyCount
    # Objective: Find all the cat keys with 0 or 1 visible items.
    # Method: Stream all the ckeys with hold and visible copy counts, and output only those with less than two (2) visible copies.
    logit "generating list of last copies ($LAST_COPY_LIST)"
    cat $allCKeyHoldCountVisibleCopyCount | pipe.pl -C c2:le$CIRC_COPIES >$LAST_COPY_LIST
    [ -s "$LAST_COPY_LIST" ] || logerr "failed to create last copy list $LAST_COPY_LIST."
    if [ "$DEBUG" == false ]; then
        rm $allActiveHoldCKeys
        rm $allAHCItemLocations
        rm $allVisibleItems
        rm $visibleItemCount
        rm $allCKeyHoldCountVisibleCopyCount
    fi
}

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "circ_copies:,debug,help,log:,version,VARS,xhelp" -o "c:dhl:vVx" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"
while true
do
    case $1 in
    -c|--circ_copies)
        shift
        CIRC_COPIES=$1
        logit "setting circulatable copies to $CIRC_COPIES"
        ;;
    -d|--debug)
        DEBUG=true
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    -l|--log)
        shift
        ALT_LOG=$1
        logit "adding logging to $ALT_LOG"
        ;;
    -v|--version)
        echo "$APP version: $VERSION"
        exit 0
        ;;
    -V|--VARS)
        show_vars
        ;;
    -x|--xhelp)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    esac
    shift
done
logit "== starting $APP version: $VERSION"
find_last_copies
logit "done"
