#!/bin/bash
###############################################################################
#
# Bash shell script for project lastcopy
# < Script description here >
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

# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
#######################################################################
# ***           Edit these to suit your environment               *** #
. /software/EDPL/Unicorn/EPLwork/cronjobscripts/setscriptenvironment.sh
###############################################################################
TMP=$(getpathname tmp)
WORKING_DIR=/software/EDPL/Unicorn/EPLwork/anisbet/Discards/Test
VERSION="0.01.01"
DB_SERIES=series.db
DB_HICIRC=hicirc.db
MIN_CHARGES=20
DEBUG=false
LOG=$WORKING_DIR/lastcopy.log
###############################################################################
# Display usage message.
# param:  none
# return: none
usage()
{
    cat << EOFU!
Usage: $0 [-option]
  Application to collect data for last copy.

  This application produces data that is used by acquisitions to reorder material before it is discarded.

  -c, --charges={n} sets the minimum charges all items on a title must have to make the grubby list.
  -d, --debug turn on debug logging.
  -h, --help: display usage message and exit.
  -v, --version: display application version and exit.
  -x, --xhelp: display usage message and exit.

  Version: $VERSION
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
    if [ -t 0 ]; then
        # If run from an interactive shell message STDOUT and LOG.
        echo -e "[$time] $message" | tee -a $LOG
    else
        # If run from cron do write to log.
        echo -e "[$time] $message" >>$LOG
    fi
}
logerr()
{
    local message="${1} exiting!"
    local time=$(date +"%Y-%m-%d %H:%M:%S")
    if [ -t 0 ]; then
        # If run from an interactive shell message STDOUT and LOG.
        echo -e "[$time] **error: $message" | tee -a $LOG
    else
        # If run from cron do write to log.
        echo -e "[$time] **error: $message" >>$LOG
    fi
    exit 1
}

# Produces cat keys whose items have more than $MIN_CHARGES 
charges()
{
    local output_list=$WORKING_DIR/highcirctitles.lst
    local sql=$WORKING_DIR/hicirc.sql
    ## Clean up any pre-existing database.
    [ -f "$WORKING_DIR/$DB_HICIRC" ] && rm $WORKING_DIR/$DB_HICIRC
	# Create the database
    [ $DEBUG == true ] && logit "creating database"
	echo "CREATE TABLE IF NOT EXISTS Charges (ckey INT,total INT);" | sqlite3 $WORKING_DIR/$DB_HICIRC
	# Select all items but do it from the cat keys because selitem 
	# reports items with seq. and copy numbers that don't exist.
	# To fix that select all the titles, then ask selitem to output
	# all the items on the title.
	[ $DEBUG == true ] && logit "creating SQL from catalog selection"
	selcatalog -oC 2>/dev/null | selitem -iC -oId 2>/dev/null | pipe.pl -oc0,c3 | awk -f hicirc.awk >$sql 
    [ $DEBUG == true ] && logit "done"
    if [ ! -s "$sql" ]; then logerr "no sql statements were generated."; fi
    [ $DEBUG == true ] && logit "loading data"
	cat $sql | sqlite3 $WORKING_DIR/$DB_HICIRC
    [ $DEBUG == true ] && logit "done"
    [ $DEBUG == true ] && logit "adding index."
    echo "CREATE INDEX IF NOT EXISTS idx_ckey ON Charges (ckey);" | sqlite3 $WORKING_DIR/$DB_HICIRC
    [ $DEBUG == true ] && logit "done"
	# Find all the cat keys who's items all have more than 
	# $MIN_CHARGES charges.
    [ $DEBUG == true ] && logit "starting selection query"
    if [ ! -s "$output_list" ]; then logerr "no sql statements were generated."; fi
	echo "SELECT ckey FROM Charges GROUP BY ckey HAVING min(total) >= $MIN_CHARGES;" | sqlite3 $WORKING_DIR/$DB_HICIRC >$output_list
    [ $DEBUG == true ] && logit "done"
    ## Clean up the database perhaps optionally.
    # [ ! $DEBUG ] && rm $WORKING_DIR/$DB_HICIRC
    logit "hi-circ list $output_list created"
}

### End of function declarations

logit "== starting $0 version: $VERSION"
### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "charges:,debug,help,version,xhelp" -o "c:dhvx" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"
while true
do
    case $1 in
    -c|--charges)
		shift
        logit "compile titles with min charges $1"
		MIN_CHARGES=$1
		charges
		;;
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
logit "== done =="
exit 0
# EOF
