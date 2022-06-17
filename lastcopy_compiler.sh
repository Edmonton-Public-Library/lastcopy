#!/bin/bash
###############################################################################
#
# Bash shell script for project lastcopy
# 
#    Copyright (C) 2021  Andrew Nisbet, Edmonton Public Library
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
. /software/EDPL/Unicorn/EPLwork/cronjobscripts/setscriptenvironment.sh
#######################################################################
WORKING_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/LastCopy
APP=$(basename -s .sh $0)
VERSION="1.01.01"
DEBUG=false
LOG=$WORKING_DIR/${APP}.log
ALT_LOG=/dev/null
SHOW_VARS=false
LASTCOPY_TITLES="$WORKING_DIR/lastcopy.lst"
## Use the checkouts on items and summarize in query.
# LASTCOPY_GRUBBY="$WORKING_DIR/grubby.lst"
LASTCOPY_SERIES="$WORKING_DIR/series.lst"
APPSNG_TITLES="$WORKING_DIR/last_copy_titles.table"
APPSNG_ITEMS="$WORKING_DIR/last_copy_items.table"
APPSNG_SERIES="$WORKING_DIR/last_copy_series.table"
###############################################################################
# Display usage message.
# param:  none
# return: none
usage()
{
    cat << EOFU!
Usage: $0 [-option]
 Compiles all the data required for lastcopy_driver.sh to use to load into appsng's lastcopy
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
    local time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$time] $message" | tee -a $LOG
}
# Logs messages as an error and exits with status code '1'.
logerr()
{
    local message="${1} exiting!"
    local time=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "[$time] **error: $message" | tee -a $LOG
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
    tmpfile=$(mktemp $WORKING_DIR/${APP}-script.XXXXXX)
    # Add a '-1' to indicate that number of title holds is not collected for titles that are not last copy titles.
    # Any other integer is mis-leading.
    selcatalog -oCtRyF 2>/dev/null | pipe.pl -m c4:"-1\|#" -P >${tmpfile}
    # 1000044|Caterpillar to butterfly / Laura Marsh|Marsh, Laura F.|2012|NLC|epl000001934  |
    logit "appending last-copy title records."
    cat $LASTCOPY_TITLES | selcatalog -iC -oCtRySF 2>/dev/null | pipe.pl -oc4,c6,exclude -tc7 -P >>${tmpfile}
    logit "de-duplicating last-copy titles,"
    # de-duplicate last-copy titles, leaves a unique list of last copy titles and non-lastcopy titles.
    cat ${tmpfile} | pipe.pl -dc0 >$APPSNG_TITLES
    # Save for checking.
    [ "$DEBUG" == false ] && rm ${tmpfile}
    # Here the items' data are collected.
    ## Lastcopy.lst contents and format.
    # CKey,NumItems,NumTHolds,NumCircable
    # 1000044|3|1|1|
    # Will become the following.
    # 31221100061618|1000009|0|AUDIOBOOK|AUDBK|0|20211215|20211206|
    # 31221100997456|1000012|1|DISCARD|JBOOK|0|20220302|20220302|
    logit "compiling item information."
    # TODO: add Call number (shelving key) DONE but needs testing.
    cat $LASTCOPY_TITLES | selitem -iC -oNBCdmthan 2>/dev/null | selcallnum -iN -oSD 2>/dev/null | pipe.pl -tc0 -mc6:'####-##-##',c7:'####-##-##' >$APPSNG_ITEMS
    # 31221100061618|1000009|0|AUDIOBOOK|AUDBK|0|2021-12-15|2021-12-06|Easy readers A PBK|
    # 31221100997456|1000012|1|DISCARD|JBOOK|0|2022-03-02|2022-03-02|Easy readers A PBK|
    ## Series information.
    [ -s "$LASTCOPY_SERIES" ] || { logit "Creating new series list. This can take some time."; ~/Unicorn/Bincustom/series.sh --CSV; }
    [ -s "$LASTCOPY_SERIES" ] || logerr "Failed to create series list!"
    # CKey,Series
    # 211|North of 52 Collection|
    # 215|North of 52 Collection|
    logit "compiling series information."
    cp $LASTCOPY_SERIES $APPSNG_SERIES
}

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "debug,help,version,VARS,xhelp" -o "dhvVx" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
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
        exit 0
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
# Find all the cat keys who's items all have more than $MIN_CHARGES charges.
[ "$SHOW_VARS" == true ] && show_vars
compile_lastcopy_lists
logit "== done =="
exit 0
# EOF
