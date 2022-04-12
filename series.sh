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
# Goal make a list of all titles grouped by series.
#
# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
#######################################################################
# ***           Edit these to suit your environment               *** #
. ~/.bashrc
#######################################################################
APP=$(basename -s .sh $0)
VERSION="1.02.00"
WORKING_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/LastCopy
# WORKING_DIR=/software/EDPL/Unicorn/EPLwork/anisbet/Discards/Test
TMP_DIR=/tmp
LOG=$WORKING_DIR/${APP}.log
ALT_LOG=/dev/null
SERIES_LIST=$WORKING_DIR/${APP}.lst
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
 Creates a list of all cat keys and their associated series
 in pipe-delimited format.
   ckey|series|

 -C, --CSV: Output as CSV with headings.
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
    logit "\$SERIES_LIST=$SERIES_LIST"
    logit "\$DEBUG=$DEBUG"
    logit "\$OUTPUT_CSV=$OUTPUT_CSV"
}
# Finds titles with last, or near to last copies in circulation.
compile_series()
{
    local allSeriesTitles=$TMP_DIR/${APP}_all_series_titles_ckey_series.lst
    local onlySeriesTitles=$TMP_DIR/${APP}_only_series_ckey_series.lst
    # This is an expensive request to check how old the list is before starting again.
    if [ -s "$SERIES_LIST" ]; then
        local yesterday=$(date -d 'now - 1 days' +%s)
        local db_age=$(date -r "$SERIES_LIST" +%s)
        if (( db_age >= yesterday )); then
            # keep the list.
            logit "$SERIES_LIST is less than a day old, using the existing catalog selection."
            return
        fi
    fi
    # Find all the titles and their 380 and 490 fields.
    logit "selecting titles and information in the 380 and 490 fields."
    selcatalog -oCe -e380,490 2>/dev/null >$allSeriesTitles
    [ -s "$allSeriesTitles" ] || logerr "no titles itendified."
    # The list should look as follows.
    # 2012345|-|Mistakes we both made ; vol. 9
    # Use either the 380 or 490 as the actual field. Cataloguers seem to prefer the 490.
    #  Once selected remove the text after the ';' since it varies sometimes by volume.
    logit "starting selection of titles with series info: $onlySeriesTitles"
    cat $allSeriesTitles | pipe.pl -B c1,c2 | pipe.pl -O c2,c1 | pipe.pl -o c0,c2 >$onlySeriesTitles
    # Remove any text after any ' ; ' which is used as the delimiter to the specific volumne information, and get rid of punctuation.
    logit "cleaning series info: $SERIES_LIST"
    cat $onlySeriesTitles | pipe.pl -W' ; ' -o c0 | pipe.pl -e c1:normal_P -P >$SERIES_LIST
    if [ "$OUTPUT_CSV" == true ]; then
        cat $SERIES_LIST | pipe.pl -oc0,c1 -TCSV_UTF-8:'CKey,Series' >${SERIES_LIST}.csv
    fi

    [ -s "$SERIES_LIST" ] || logerr "failed to series list $SERIES_LIST."
    if [ "$DEBUG" == false ]; then
        rm $allSeriesTitles
        rm $onlySeriesTitles
    fi
}

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "CSV,debug,help,log:,version,VARS,working_dir:,xhelp" -o "Cdhl:vVw:x" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"
while true
do
    case $1 in
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
        SERIES_LIST=$WORKING_DIR/${APP}.lst
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
compile_series
logit "done"
