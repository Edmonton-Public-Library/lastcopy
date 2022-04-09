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
VERSION="1.01.03"
TMP_DIR=/tmp
WORKING_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/LastCopy
LOG=$WORKING_DIR/${APP}.log
ALT_LOG=/dev/null
LAST_COPY_LIST=$WORKING_DIR/${APP}.lst
# Used as a regex with pipe.pl
NON_CIRC_LOCATIONS='UNKNOWN|MISSING|LOST|DISCARD|LOST-PAID|LONGOVRDUE|CANC_ORDER|INCOMPLETE|DAMAGE|BARCGRAVE|NON-ORDER|LOST-ASSUM|LOST-CLAIM|STOLEN|NOF|ILL'
DEBUG=false
CIRC_COPIES=1
# Items in these locations don't count agains charges.
EXCLUDE_ITYPES='~UNKNOWN,ILL-BOOK,AV,AV-EQUIP,MICROFORM,NEWSPAPER,EQUIPMENT,E-RESOURCE,JCASSETTE,RFIDSCANNR'
SHOW_VARS=false
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
 -d, --debug turn on debug logging, write scratch files to the 
   working directory (see -w), and do not remove scratch files.
 -h, --help: display usage message and exit.
 -l, --log=<path>: Appends logging to another log file.
 -v, --version: display application version and exit.
 -V, --VARS: Show variables used.
 -w, --working_dir=</foo/bar>: Set the working directory where report
   output will be written.
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
    local allItemCKeys=$TMP_DIR/${APP}_all_ckeys_item_count_zero_holds.lst
    local allActiveHoldCKeys=$TMP_DIR/${APP}_all_active_holds_ckey.lst
    local mergedCKeysICountsHolds=$TMP_DIR/${APP}_all_ckeys_ckeycount_holdcount.lst
    local allItemLocations=$TMP_DIR/${APP}_all_active_holds_items_loc.lst
    local allVisibleItems=$TMP_DIR/${APP}_all_visible_items.lst
    local visibleItemCount=$TMP_DIR/${APP}_visible_item_count.lst
    local allCKeyHoldCountVisibleCopyCount=$TMP_DIR/${APP}_all_ckey_hold_count_visible_copy_count.lst
    # Find all the ckeys for all items and make a zero hold list that matches format of the (next)
    # active holds list. This will give us a list of all last copies - with or without holds.
    # Method: select items not of the 'exclude' type, add total ckeys reversing order do ckey comes first.
    # Example: 1005442|1|
    logit "selecting all items excluding $EXCLUDE_ITYPES"
    selitem -oC | pipe.pl -dc0 -A -P | pipe.pl -o reverse -P >$allItemCKeys
    [ -s "$allItemCKeys" ] || logerr "no items found??"
    # Find the count of active holds on each title.
    # Method: Select all the active holds, output their cat keys, dedup outputting the count and put the count on the end of each line.
    # Example: 1012345|5
    logit "selecting active holds"
    selhold -jACTIVE -oC 2>/dev/null | pipe.pl -dc0 -A -P | pipe.pl -o reverse >$allActiveHoldCKeys
    [ -s "$allActiveHoldCKeys" ] || logerr "no active holds found."
    # Take the list of all ckeys with counts but no holds, and merge the list of all ckeys with holds.
    # Method: in a list of all ckeys, and ckeys with holds, if the ckeys match append the number of holds 
    # and zero '0' otherwise.
    # 1000044|1|0|
    # 1000045|2|1|
    # 1000056|7|3|
    logit "merging ckeys with item counts with ckeys with active hold counts"
    cat $allItemCKeys | pipe.pl -0 $allActiveHoldCKeys -M c0:c0?c1.0 -P >$mergedCKeysICountsHolds
    # Given the list of cat keys with holds, find the locations of the items.
    # Method: Pipe cat keys into selitem outputting the cat key (barcode used for checking only) and location.
    # Example: 
    # 1000044|31221116612420  |DISCARD|1|0|
    # 1000044|31221116612396  |INTRANSIT|1|0|
    # 1000056|31221101053291  |HOLDS|7|3|
    logit "selecting items on titles with active holds"
    cat $mergedCKeysICountsHolds | selitem -iC -oCBmS 2>/dev/null >$allItemLocations
    [ -s "$allItemLocations" ] || logerr "no items found."
    # Make a new list of items with only non-shadowed locations.
    # Method: Pipe the items and exclude hidden non-circulatable locations and save the list.
    # Example:
    # 1000044|31221116612396  |INTRANSIT|
    # 1000056|31221101053291  |HOLDS|
    [ "$DEBUG" == true ] && logit "removing items with non-circ locations."
    cat $allItemLocations | pipe.pl -Gc2:"($NON_CIRC_LOCATIONS)" >$allVisibleItems
    [ -s "$allVisibleItems" ] || logit "no visible items found."
    # Find all the cat ckeys and a count of circulatable items.
    # Mehod: De-duplicate all circulateable cat keys and add the count of duplicates to the end of each line.
    # Example:
    # 1000044|1
    # 1000056|1
    # 1000084|3
    [ "$DEBUG" == true ] && logit "computing visible copy count for titles."
    cat $allVisibleItems | pipe.pl -dc0 -A -P | pipe.pl -o c1,c0 >$visibleItemCount
    # Match ckeys with holds with ckeys with visible copies.
    # Method: pipe all the cat keys with holds, merge with the list of visible item counts, and if a cat key with holds
    #  matches a cat key with visible copies, add the visible copy count, otherwise add a zero (0).
    # 1000044|1|0|0|
    # 1000045|2|1|1|
    # 1000056|7|3|7|
    [ "$DEBUG" == true ] && logit "merging hold and visible copy lists."
    cat $mergedCKeysICountsHolds | pipe.pl -0 $visibleItemCount -M c0:c0?c1.0 >$allCKeyHoldCountVisibleCopyCount
    # Find all the cat keys with 0 or 1 visible items.
    # Method: Stream all the ckeys with hold and visible copy counts, and output only those with less than two (2) visible copies.
    logit "generating list of last copies ($LAST_COPY_LIST)"
    cat $allCKeyHoldCountVisibleCopyCount | pipe.pl -C c3:le$CIRC_COPIES -P >$LAST_COPY_LIST
    [ -s "$LAST_COPY_LIST" ] || logerr "failed to create last copy list $LAST_COPY_LIST."
    if [ "$DEBUG" == false ]; then
        rm $allItemCKeys
        rm $allActiveHoldCKeys
        rm $mergedCKeysICountsHolds
        rm $allItemLocations
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
options=$(getopt -l "circ_copies:,debug,help,log:,version,VARS,working_dir:,xhelp" -o "c:dhl:vVw:x" -a -- "$@")
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
        SHOW_VARS=true
        ;;
    -w|--working_dir)
        shift
        WORKING_DIR=$1
        # Update the location of the last copy list since working dir has changed.
        LAST_COPY_LIST=$WORKING_DIR/${APP}.lst
        logit "setting working directory to $WORKING_DIR"
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
# If the debug is on set the temp dir to working directory to make file checks easier.
[ "$DEBUG" == true ] && TMP_DIR=$WORKING_DIR 
logit "== starting $APP version: $VERSION"
[ "$SHOW_VARS" == true ] && show_vars
find_last_copies
logit "done"
