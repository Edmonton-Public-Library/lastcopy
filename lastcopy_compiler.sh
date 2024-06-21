#!/bin/bash
###############################################################################
#
# Bash shell script for project lastcopy
# 
#    Copyright (C) 2022 - 2024  Andrew Nisbet, Edmonton Public Library
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
# Takes lists created by lastcopy.sh, series.sh, and grubby.sh and compiles
# data needed for importing into appsng database.
#
# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
#######################################################################
# ***           Edit these to suit your environment               *** #
. ~/.bashrc
#######################################################################
WORKING_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/LastCopy
APP=$(basename -s .sh "$0")
# This version removes ON-ORDER from non-circ locations filter.
VERSION="1.02.03"
DEBUG=false
LOG="$WORKING_DIR/${APP}.log"
ALT_LOG=/dev/null
SHOW_VARS=false
LASTCOPY_TITLES="$WORKING_DIR/lastcopy.lst"
## Use the checkouts on items and summarize in query.
# LASTCOPY_GRUBBY="$WORKING_DIR/grubby.lst"
LASTCOPY_SERIES="$WORKING_DIR/series.lst"
APPSNG_TITLES="$WORKING_DIR/last_copy_titles.table"
APPSNG_ITEMS="$WORKING_DIR/last_copy_items.table"
APPSNG_SERIES="$WORKING_DIR/last_copy_series.table"
NON_CIRC_LOCATIONS="UNKNOWN|MISSING|LOST|DISCARD|LOST-PAID|LONGOVRDUE|CANC_ORDER|INCOMPLETE|DAMAGE|BARCGRAVE|NON-ORDER|LOST-ASSUM|LOST-CLAIM|STOLEN|NOF|ILL"
IGNORE_TYPES='UNKNOWN|ILL-BOOK|AV|AV-EQUIP|MICROFORM|NEWSPAPER|EQUIPMENT|E-RESOURCE|JCASSETTE|RFIDSCANNR|JOTHLANGBK|OTHLANGBK|PERIODICAL|JPERIODICL'
###############################################################################
# Display usage message.
# param:  none
# return: none
usage()
{
    cat << EOFU!
Usage: $0 [-option]
 Compiles all the data required for lastcopy_driver.sh to use to load into appsng lastcopy
 application.

 -d, --debug turn on debug logging.
 -h, --help: display usage message and exit.
 -v, --version: display application version and exit.
 -V, --VARS: Display all the variables set in the script.
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
    local current_time=''
    current_time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$current_time] $message" | tee -a "$LOG"
}
# Logs messages as an error and exits with status code '1'.
logerr()
{
    local message="${1} exiting!"
    local current_time=''
    current_time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$current_time] **error: $message" | tee -a "$LOG"
    exit 1
}

# Displays a list of all the variables set in the script.
show_vars()
{
    echo "\$WORKING_DIR=$WORKING_DIR"
    echo "\$VERSION=$VERSION"
    echo "\$DEBUG=$DEBUG"
    echo "\$LOG=$LOG"
    echo "\$ALT_LOG=$ALT_LOG"
    echo "\$LASTCOPY_TITLES=$LASTCOPY_TITLES"
    echo "\$LASTCOPY_SERIES=$LASTCOPY_SERIES"
    echo "\$APPSNG_TITLES=$APPSNG_TITLES"
    echo "\$APPSNG_ITEMS=$APPSNG_ITEMS"
    echo "\$APPSNG_SERIES=$APPSNG_SERIES"
}

compile_lastcopy_lists()
{
    # If there is already a list keep it. It takes a long time to generate.
    # The lastcopy.sh script is scheduled to run before this script.
    [ -s "$LASTCOPY_TITLES" ] || { logit "Creating new titles list."; ~/Unicorn/Bincustom/lastcopy.sh --CSV; }
    [ -s "$LASTCOPY_TITLES" ] || logerr "Failed to create last copy list!"
    # The input to the next process comes from 'lastcopy.lst', and is formatted as follows.
    # CKey,NumItems,NumTHolds,NumCircable
    # 1000044|3|1|1|
    # The next command adds all the information for generating title SQL statements.
    # 1000031|Un hombre arrogante / Kim Lawrence|Lawrence, Kim|2011|1|0|0|a1000031|
    # 1000033|Noche de amor en Río / Jennie Lucas|Lucas, Jennie|2011|1|0|1|a1000033|
    # Collect all the titles, adding NLC as placeholders for item information. Later 
    # append the last copy item information, then dedup the list. Dedup in pipe.pl
    # naturally saves the last duplicate which will be the title with last copy information
    # or NLC if the title doesn't have last copies.
    logit "compiling all titles."
    tmpfile=$(mktemp "$WORKING_DIR/${APP}-script-1.XXXXXX")
    # Add a '-1' to indicate that number of title holds is not collected for titles that are not last copy titles.
    # Any other integer is mis-leading.
    selcatalog -oCtRyFe -e092,099 2>/dev/null | pipe.pl -m c4:"-1\|#" -tc4 -P >"$tmpfile"
    # 1000044|Caterpillar to butterfly / Laura Marsh|Marsh, Laura F.|2012|-1|epl000001934|-|E MAR|
    logit "appending last-copy title records."
    selcatalog -iC -oCtRySFe -e092,099 <"$LASTCOPY_TITLES" 2>/dev/null | pipe.pl -oc4,c6,exclude -tc7 -P >>"$tmpfile"
    # 1000044|Caterpillar to butterfly / Laura Marsh|Marsh, Laura F.|2012|1|epl000001934|-|E MAR|
    logit "de-duplicating last-copy titles,"
    # de-duplicate last-copy titles, leaves a unique list of last copy titles and non-lastcopy titles.
    pipe.pl -dc0 <"$tmpfile" >"$APPSNG_TITLES"
    logit "collecting fiction or nonfiction values."
    tmpfile2=$(mktemp "$WORKING_DIR/${APP}-script-2.XXXXXX")
    # Collect the fiction or non-fiction values of titles. It's the 33rd character in the 008 field (#34 for pipe.pl). Some titles don't have it tho.
    selcatalog -iC -oCe -e008 <"$APPSNG_TITLES" 2>/dev/null | pipe.pl -mc1:_________________________________#_ -oc0,c1 -P >"$tmpfile2"
    # This places 'n' for non-fiction and 'y' for is_fiction in the last column in the last_copy_titles.table file.
    pipe.pl -0"$tmpfile2" -Mc0:c0?c1.n -P <"$APPSNG_TITLES" | pipe.pl -fc8:0.1?y.n >"$tmpfile"
    # Overwrite the last_copy_titles.table with the appended fiction or nonfiction values.
    cp "$tmpfile" "$APPSNG_TITLES"
    # The last_copy_titles.table now looks like this:
    # 1000030|The Augustan poets [videorecording]|Whelan, Robert|2006|-1|a1000030|DVD 821.508 AUG|-|n|
    # 1000031|Un hombre arrogante / Kim Lawrence|Lawrence, Kim|2011|0|a1000031|-|Spanish LAW|y|
    # 1000033|Noche de amor en Río / Jennie Lucas|Lucas, Jennie|2011|0|a1000033|-|Spanish LUC|y|
    [ "$DEBUG" == false ] && rm "$tmpfile" "$tmpfile2"
    # Here the items' data are collected.
    ## Lastcopy.lst contents and format.
    # CKey,NumItems,NumTHolds,NumCircable
    # 1000044|3|1|1|
    # Will become the following.
    # 31221100061618|1000009|0|AUDIOBOOK|AUDBK|0|20211215|20211206|
    # 31221100997456|1000012|1|DISCARD|JBOOK|0|20220302|20220302|
    logit "compiling item information."
    # Add Call number (shelving key).
    # selitem -o N-CallNum(ckey,callNum),B-BCode,C-CatKey,d-TotalChrgs,m-CurrLoc,t-iType,h-CopyHoldNum,a-LastActivity,n-LastCharged,l-HomeLoc,g-ItemCat2
    #                       0, 1,          2,      3,       4,           5,        6,        7,            8,             9,           10,       11
    selitem -iC -oNBCdmthanlg <"$LASTCOPY_TITLES" 2>/dev/null | pipe.pl -G"c5:($NON_CIRC_LOCATIONS),c6:($IGNORE_TYPES)" | selcallnum -iN -oSD 2>/dev/null | pipe.pl -tc0 -mc6:'####-##-##',c7:'####-##-##' >"$APPSNG_ITEMS"
    # 31221100061618|1000009|0|AUDIOBOOK|AUDBK|0|2021-12-15|2021-12-06|TEENNCOLL|YA|Easy readers A PBK|
    # 31221100997456|1000012|1|DISCARD|JBOOK|0|2022-03-02|2022-03-02|TEENVIDGME|ADULT|Easy readers A PBK|
    ## Series information.
    [ -s "$LASTCOPY_SERIES" ] || { logit "Creating new series list. This can take some time."; ~/Unicorn/Bincustom/series.sh --CSV; }
    [ -s "$LASTCOPY_SERIES" ] || logerr "Failed to create series list!"
    # CKey,Series
    # 211|North of 52 Collection|
    # 215|North of 52 Collection|
    logit "compiling series information."
    cp "$LASTCOPY_SERIES" "$APPSNG_SERIES"
}

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "debug,help,version,VARS,xhelp" -o "dhvVx" -a -- "$@")
[ $? != 0 ] && logerr "Failed to parse options...exiting."
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"
while true
do
    case $1 in
    -d|--debug)
        logit "turning on debugging"
		DEBUG=true
		;;
    -h|--help)
        usage
        ;;
    -v|--version)
        echo "$0 version: $VERSION"
        exit 0
        ;;
    -V|--VARS)
        show_vars
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
logit "== starting $APP version: $VERSION"
# Find all the cat keys who's items all have more than $MIN_CHARGES charges.
[ "$SHOW_VARS" == true ] && show_vars
compile_lastcopy_lists
logit "== done =="
exit 0
# EOF
