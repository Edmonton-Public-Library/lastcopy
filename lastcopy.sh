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
VERSION="1.03.01"
WORKING_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/LastCopy
LOG=$WORKING_DIR/${APP}.log
ALT_LOG=/dev/null
LAST_COPY_LIST=$WORKING_DIR/${APP}.lst
# Used as a regex with pipe.pl
NON_CIRC_LOCATIONS='UNKNOWN|MISSING|LOST|DISCARD|LOST-PAID|LONGOVRDUE|CANC_ORDER|INCOMPLETE|DAMAGE|BARCGRAVE|NON-ORDER|LOST-ASSUM|LOST-CLAIM|STOLEN|NOF|ILL'
DEBUG=false
CIRC_COPIES=1
# Items in these locations don't count agains charges.
# Note that DO NOT include a tilde for negation, that's done later during selection.
IGNORE_TYPES='UNKNOWN,ILL-BOOK,AV,AV-EQUIP,MICROFORM,NEWSPAPER,EQUIPMENT,E-RESOURCE,JCASSETTE,RFIDSCANNR'
SHOW_VARS=false
OUTPUT_CSV=false
####### Functions ########
# Display usage message.
# param:  none
# return: none
usage()
{
    cat << EOFU!
Usage: $0 [-option]
 Creates a list of catalog keys, count of items on the title
 hold count on the title, and visible copy counts in pipe-delimited format.
   ckey|item count|title hold count|circulatable copy count|

 -c, --circ_copies=<integer> Sets the upper bound of circulate-able
   copies a title must have to make it to the 'last copy' list.
   Default is $CIRC_COPIES or less, which is usually fine.
 -C, --CSV: Output as CSV with headings.
 -d, --debug turn on debug logging, write scratch files to the 
   working directory (see -w), and do not remove scratch files.
 -h, --help: display usage message and exit.
 -i, --ignore<TYPE_1,TYPE_2,...>: Ignore these item types.
   The default is $IGNORE_TYPES. Do not add the '~', and separate
   multiple values with ','.
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
    logit "\$WORKING_DIR=$WORKING_DIR"
    logit "\$LOG=$LOG"
    logit "\$ALT_LOG=$ALT_LOG"
    logit "\$LAST_COPY_LIST=$LAST_COPY_LIST"
    logit "\$NON_CIRC_LOCATIONS=$NON_CIRC_LOCATIONS"
    logit "\$DEBUG=$DEBUG"
    logit "\$CIRC_COPIES=$CIRC_COPIES"
    logit "\$OUTPUT_CSV=$OUTPUT_CSV"
    logit "\$IGNORE_TYPES=$IGNORE_TYPES"
}
# Finds titles with last, or near to last copies in circulation.
find_last_copies()
{
    ## @TODO: Remove e-resources and ILL items.
    local all_CKeyItemCount=$WORKING_DIR/${APP}_all_ckey_itemcount.lst
    local allActiveHolds_CKeyCount=$WORKING_DIR/${APP}_all_activeholds_ckey_holdcount.lst
    local merged_CKeyItemCountHoldCount=$WORKING_DIR/${APP}_merged_ckey_itemcount_holdcount.lst
    local allItems_CKeyBCodeLocationItemCountHoldCount=$WORKING_DIR/${APP}_all_items_ckey_bcode_location_itemcount_holdcount.lst
    local allVisibleItems_CKeyBCodeLocationItemCountHoldCount=$WORKING_DIR/${APP}_all_visible_items_ckey_bcode_location_itemcount_holdcount.lst
    local visibleItems_ItemCount=$WORKING_DIR/${APP}_visible_items_ckey_itemcount.lst
    local all_CKeyItemCountHoldCountVisibleCopyCount=$WORKING_DIR/${APP}_all_ckey_itemcount_holdcount_visiblecopycount.lst
    # Find all the ckeys for all items and make a zero hold list that matches format of the (next)
    # active holds list. This will give us a list of all last copies - with or without holds.
    # Method: select items not of the 'exclude' type, add total ckeys reversing order do ckey comes first.
    # Example: 1005442|1|
    logit "selecting all items excluding $IGNORE_TYPES"
    # While selecting the initial cat keys I grep out temp items, that is, items with '-' in their barcodes.
    selitem -t"~$IGNORE_TYPES" -oCB 2>/dev/null | grep -v "-" | pipe.pl -o c0 | pipe.pl -dc0 -A -P | pipe.pl -o reverse -P >$all_CKeyItemCount
    [ -s "$all_CKeyItemCount" ] || logerr "no items found??"
    ## TODO: add total circs to the list of data collected.
    # Find the count of active holds on each title.
    # Method: Select all the active holds, output their cat keys, dedup outputting the count and put the count on the end of each line.
    # Example: 1012345|5
    logit "selecting active holds"
    selhold -jACTIVE -oC 2>/dev/null | pipe.pl -dc0 -A -P | pipe.pl -o reverse -P >$allActiveHolds_CKeyCount
    [ -s "$allActiveHolds_CKeyCount" ] || logerr "no active holds found."
    # Take the list of all ckeys with counts but no holds, and merge the list of all ckeys with holds.
    # Method: in a list of all ckeys, and ckeys with holds, if the ckeys match append the number of holds 
    # and zero '0' otherwise.
    # 1000044|1|0|
    # 1000045|2|1|
    # 1000056|7|3|
    logit "merging ckeys with item counts with ckeys with active hold counts"
    cat $all_CKeyItemCount | pipe.pl -0 $allActiveHolds_CKeyCount -M c0:c0?c1.0 -P >$merged_CKeyItemCountHoldCount
    # Given the list of cat keys with holds, find the locations of the items.
    # Method: Pipe cat keys into selitem outputting the cat key (barcode used for checking only) and location.
    # Example: 
    # 1000044|31221116612420  |DISCARD|1|0|
    # 1000044|31221116612396  |INTRANSIT|1|0|
    # 1000056|31221101053291  |HOLDS|7|3|
    logit "selecting items on titles with active holds"
    # Here again don't pass on the temp items.
    cat $merged_CKeyItemCountHoldCount | selitem -iC -t"~$IGNORE_TYPES" -oCBmS 2>/dev/null | pipe.pl -Gc1:"-" -P >$allItems_CKeyBCodeLocationItemCountHoldCount
    [ -s "$allItems_CKeyBCodeLocationItemCountHoldCount" ] || logerr "no items found."
    # Make a new list of items with only non-shadowed locations.
    # Method: Pipe the items and exclude hidden non-circulatable locations and save the list.
    # Example:
    # 1000044|31221116612396  |INTRANSIT|
    # 1000056|31221101053291  |HOLDS|
    [ "$DEBUG" == true ] && logit "removing items with non-circ locations."
    cat $allItems_CKeyBCodeLocationItemCountHoldCount | pipe.pl -Gc2:"($NON_CIRC_LOCATIONS)" >$allVisibleItems_CKeyBCodeLocationItemCountHoldCount
    [ -s "$allVisibleItems_CKeyBCodeLocationItemCountHoldCount" ] || logit "no visible items found."
    # Find all the cat ckeys and a count of circulatable items.
    # Mehod: De-duplicate all circulateable cat keys and add the count of duplicates to the end of each line.
    # Example:
    # 1000044|1
    # 1000056|1
    # 1000084|3
    [ "$DEBUG" == true ] && logit "computing visible copy count for titles."
    cat $allVisibleItems_CKeyBCodeLocationItemCountHoldCount | pipe.pl -dc0 -A -P | pipe.pl -o c1,c0 >$visibleItems_ItemCount
    # Match ckeys with holds with ckeys with visible copies.
    # Method: pipe all the cat keys with holds, merge with the list of visible item counts, and if a cat key with holds
    #  matches a cat key with visible copies, add the visible copy count, otherwise add a zero (0).
    # 1000044|1|0|0|
    # 1000045|2|1|1|
    # 1000056|7|3|7|
    [ "$DEBUG" == true ] && logit "merging hold and visible copy lists."
    cat $merged_CKeyItemCountHoldCount | pipe.pl -0 $visibleItems_ItemCount -M c0:c0?c1.0 -P >$all_CKeyItemCountHoldCountVisibleCopyCount
    # Find all the cat keys with 0 or 1 visible items.
    # Method: Stream all the ckeys with hold and visible copy counts, and output only those with less than $CIRC_COPIES visible copies.
    logit "generating list of last copies ($LAST_COPY_LIST)"
    cat $all_CKeyItemCountHoldCountVisibleCopyCount | pipe.pl -C c3:le$CIRC_COPIES -P >$LAST_COPY_LIST
    [ "$OUTPUT_CSV" == true ] && cat $LAST_COPY_LIST | pipe.pl -oc0,c1,c2,c3 -TCSV_UTF-8:'CKey,NumItems,NumTHolds,NumCircable' >${LAST_COPY_LIST}.csv
    [ -s "$LAST_COPY_LIST" ] || logerr "failed to create last copy list $LAST_COPY_LIST."
    if [ "$DEBUG" == false ]; then
        rm $all_CKeyItemCount
        rm $allActiveHolds_CKeyCount
        rm $merged_CKeyItemCountHoldCount
        rm $allItems_CKeyBCodeLocationItemCountHoldCount
        rm $allVisibleItems_CKeyBCodeLocationItemCountHoldCount
        rm $visibleItems_ItemCount
        rm $all_CKeyItemCountHoldCountVisibleCopyCount
    fi
}

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "circ_copies:,CSV,debug,help,ignore:,log:,version,VARS,working_dir:,xhelp" -o "c:Cdhi:l:vVw:x" -a -- "$@")
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
    -C|--CSV)
        OUTPUT_CSV=true
        logit "setting output to CSV"
        ;;
    -d|--debug)
        DEBUG=true
        ;;
    -h|--help)
        usage
        exit 0
        ;;
    -i|--ignore)
        shift
        IGNORE_TYPES="$1"
        logit "adding rule to ignore $IGNORE_TYPES"
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
logit "== starting $APP version: $VERSION"
[ "$SHOW_VARS" == true ] && show_vars
find_last_copies
logit "== done =="
exit 0
