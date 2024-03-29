#!/bin/bash
###############################################################################
#
# Bash shell script for project lastcopy
# 
#    Copyright (C) 2022 - 2024 Andrew Nisbet, Edmonton Public Library
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
# Goal make a list of all the items or titles that have more than a
# an arbitrary but specific number of circulatable copies.
#
# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
#######################################################################
# ***           Edit these to suit your environment               *** #
. ~/.bashrc
#######################################################################
APP=$(basename -s .sh "$0")
VERSION="1.04.02"
HOSTNAME=$(hostname)
if [ "$HOSTNAME" == "ubuntu" ]; then
    WORKING_DIR=/home/anisbet/EPL/lastcopy
    IS_TEST=true
    TMP_DIR="."
    # Middling value in the test data below.
    MIN_CHARGES=23
else
    WORKING_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/LastCopy
    IS_TEST=false
    TMP_DIR="/tmp"
    MIN_CHARGES=30
fi
LOG="$WORKING_DIR/${APP}.log"
ALT_LOG=/dev/null
# Items in these locations don't count agains charges.
EXCLUDE_LOCATIONS="~UNKNOWN,CANC_ORDER,NON-ORDER,NOF,ILL"
INCLUDE_TYPES=''
GRUBBY_LIST="$WORKING_DIR/${APP}.lst"
GROUP_BY_TITLE=false
DEBUG=false
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
 Creates a list of items that have more than a given number of circs,
 or a list of titles whose items all have a minimum of a given number
 of circs.
   ckey|minimum circ count|
 or by default
   item ID|circ count|

 -c, --charges=<integer> Sets the minimum number of charges for items
   to be considered 'grubby'. If -T is used the total charges of items
   (not including $EXCLUDE_LOCATIONS) is summed up, and item counts
   are reported.
 -C, --CSV: Output as CSV with headings.
 -d, --debug turn on debug logging, write scratch files to the 
   working directory (see -w), and do not remove scratch files.
 -h, --help: display usage message and exit.
 -l, --log=<path>: Appends logging to another log file.
 -t, --type<ITYPE1,ITYPE2,...>: Sets the item types for selection.
   You may choose this to remove item types like E-RESOURCE etc.
 -T, --Titles: Sets the minimum charges (default $MIN_CHARGES, see -c)
   that all items on a title must have to make the grubby list.
   By default $APP reports select items that have at least $MIN_CHARGES
   charges minimum.
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
    local time=''
    time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$time] $message" | tee -a "$LOG" -a "$ALT_LOG"
}

# Logs messages as an error and exits with status code '1'.
logerr()
{
    local message="${1} exiting!"
    local time=''
    time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$time] **error: $message" | tee -a "$LOG" -a "$ALT_LOG"
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
    logit "\$GRUBBY_LIST=$GRUBBY_LIST"
    logit "\$DEBUG=$DEBUG"
    logit "\$MIN_CHARGES=$MIN_CHARGES"
    logit "\$OUTPUT_CSV=$OUTPUT_CSV"
}

# Finds titles with last, or near to last copies in circulation.
find_last_copies()
{
    local allItems="$TMP_DIR/${APP}_all_items_CBmtad.lst"
    # Items are selected by number of charges (-d)
    # Output should be ckey,itemId,iType,lastCharged,numCharges
    local excludeLocations="-m${EXCLUDE_LOCATIONS}"
    local selITypes=''
    [ -z "$INCLUDE_TYPES" ] || selITypes="-t${INCLUDE_TYPES}"
    [ "$DEBUG" == true ] && logit "DEBUG: \$excludeLocations=$excludeLocations"
    local test_data="131|31221007483618  |DISCARD|MUSICSCORE|20130827|27|\n134|31221039324251  |INTRANSIT|BOOK|20220407|20|\n363|31221107619467  |CHECKEDOUT|BOOK|20220405|23|"
    logit "starting item selection"
    if [ "$IS_TEST" == true ]; then
        echo -e "$test_data" >"$allItems"
    else
        selitem "$excludeLocations" "$selITypes" -oCBmtad >"$allItems" 2>/dev/null
    fi
    # Compute titles where all items have $MIN_CHARGES
    # 131|31221007483618  |DISCARD|MUSICSCORE|20130827|27|
    # 134|31221039324251  |INTRANSIT|BOOK|20220407|20|
    # 363|31221107619467  |CHECKEDOUT|BOOK|20220405|23|
    if [ "$GROUP_BY_TITLE" == true ]; then
        logit "starting group by title"
        pipe.pl -dc0 -J minc5 -P <"$allItems" | pipe.pl -oc1,c0 | pipe.pl -C c1:ge${MIN_CHARGES} -P >"$GRUBBY_LIST"
        [ "$OUTPUT_CSV" == true ] && pipe.pl -oc0,c1 -TCSV_UTF-8:'CKey,MinCircCount' <"$GRUBBY_LIST" >"${GRUBBY_LIST}.csv"
    else 
        # Restict list to items that have $MIN_CHARGES
        logit "starting select by count"
        pipe.pl -C c5:ge$MIN_CHARGES <"$allItems" | pipe.pl -tc1 -oc1,c5 -P >"$GRUBBY_LIST"
        [ "$OUTPUT_CSV" == true ] && pipe.pl -oc0,c1 -TCSV_UTF-8:'ItemID,CircCount' <"$GRUBBY_LIST" >"${GRUBBY_LIST}.csv"
    fi
    if [ -s "$GRUBBY_LIST" ]; then
        if [ "$DEBUG" == false ]; then
            rm "$allItems"
        fi
    else
        logerr "failed to create last copy list $GRUBBY_LIST."
    fi
}

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "charges:,CSV,debug,help,log:,type:,Titles,version,VARS,working_dir:,xhelp" -o "c:Cdhl:t:TvVw:x" -a -- "$@")
[ $? != 0 ] && { logit "Failed to parse options...exiting." ; exit 1 ; }
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"
while true
do
    case $1 in
    -c|--charges)
        shift
        MIN_CHARGES="$1"
        logit "setting circulatable copies to $MIN_CHARGES"
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
        ;;
    -l|--log)
        shift
        ALT_LOG="$1"
        logit "adding logging to $ALT_LOG"
        ;;
    -t|--type)
        shift
        INCLUDE_TYPES="$1"
        logit "focusing selection to $INCLUDE_TYPES item types."
        ;;
    -T|--Titles)
        GROUP_BY_TITLE=true
        logit "setting min charges of $MIN_CHARGES for ALL items on titles."
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
        WORKING_DIR="$1"
        # Update the location of the grubby list since working dir has changed.
        GRUBBY_LIST="$WORKING_DIR/${APP}.lst"
        logit "setting working directory to $WORKING_DIR"
        ;;
    -x|--xhelp)
        usage
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
logit "== done =="
exit 0
