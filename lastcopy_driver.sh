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
# Goals are to collect all the data from the ILS and import
# it into the appsng database(s).
# 
# Last copy data is collected regularly and loaded into a temporary database 
# on the ILS. The temp database makes finding data easier and tuning last copy
# parameters more flexible.
#
# Query the database for titles that broadly match circ staffs' requirements
# and batch import it into the apps ng database.
#
###############################################################################
HOME_DIR=/home/ils
WORKING_DIR=$HOME_DIR/last_copy
VERSION="0.01.00_DEV"
DB_PRODUCTION=$HOME_DIR/mysqlconfigs/lastcopy
DB_DEV=$HOME_DIR/mysqlconfigs/lastcopy_dev
ILS_WORKING_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/LastCopy
LASTCOPY_FILES="*.lst"
DEBUG=false
LOG=$WORKING_DIR/lastcopy_driver.log
DB_CMD="mysql --defaults-file"
IS_TEST=false
# These locations put a title at risk of not having circulatable copies.
DISCARD_LOCATIONS=DAMAGE,DISCARD,LOST,LOST-ASSUM,LOST-CLAIM,MISSING
NUM_HOLDS=
NUM_CIRC_COPIES=1
NUM_CHARGES=
LAST_CHARGED=
LAST_ACTIVE=
# Don't select titles where all the items on a title have these locations.
EXCLUDE_LOCATIONS="INTERNET,HOME"
# Don't select titles where all the items on a title have these item types.
EXCLUDE_ITYPES="ILL-BOOK,E-RESOURCE"
PRODUCTION_ILS='sirsi@edpl.sirsidynix.net'
TEST_ILS='sirsi@edpltest.sirsidynix.net'
SSH_SERVER=$PRODUCTION_ILS

SHOW_VARS=false
###############################################################################
# Display usage message.
# param:  none
# return: none
usage()
{
    cat << EOFU!
Usage: $0 [-options]
 Application to collect data for last copy.

 -c, --circulating_copies=<integer> Sets the upper limit of items in
   circulation for any arbitrary but specific title to be selected as
   having 'last copy' status.
 -d, --debug turn on debug logging.
 -h, --help: display usage message and exit.
 -L, --Locations_excluded<string,locations> Sets the locations to exclude
   when considering item selection. Multiple locations are separated by 
   a comma (,) and must not include spaces.
 -t, --test: Load data into the test database; $DB_DEV.
 -T, --Types_excluded<string,iTypes> Sets the item types to exclude
   when considering item selection. Multiple item types are separated by 
   a comma (,) and must not include spaces.
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
    echo "\$DB_PRODUCTION=$DB_PRODUCTION"
    echo "\$DB_DEV=$DB_DEV"
    echo "\$DEBUG=$DEBUG"
    echo "\$LOG=$LOG"
    echo "\$IS_TEST=$IS_TEST"
    echo "\$DB_CMD=$DB_CMD"
    echo "\$NUM_CIRC_COPIES=$NUM_CIRC_COPIES"
    echo "\$EXCLUDE_LOCATIONS=$EXCLUDE_LOCATIONS"
    echo "\$EXCLUDE_ITYPES=$EXCLUDE_ITYPES"
    echo "\$SSH_CMD=$SSH_CMD"
}

# Builds the queries to collect the data from the remote temp database.
collect_data()
{
    ## TODO: Set criteria and create queries for sqlite3 database.
    ## TODO: (Batch) import data into the mysql database.

    logerr "TODO: Finish me."
}

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "circulating_copies:,debug,help,Locations_excluded:,test,Types_excluded:,version,VARS,xhelp" -o "c:dhL:tT:vVx" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"
while true
do
    case $1 in
    -c|--circulating_copies)
        shift
        NUM_CIRC_COPIES=$1
        [ "$DEBUG" == true ] && logit "Setting circulation copies to ${NUM_CIRC_COPIES}."
		;;
    -d|--debug)
        [ "$DEBUG" == true ] || logit "Turning on debugging"
		DEBUG=true
		;;
    -h|--help)
        usage
        exit 0
        ;;
    -L|--Locations_excluded)
        shift
        EXCLUDE_LOCATIONS="$1"
        [ "$DEBUG" == true ] && logit "Excluding items in $EXCLUDE_LOCATIONS locations."
        ;;
    -t|--test)
        [ "$DEBUG" == true ] && logit "using test database"
        SSH_SERVER=$TEST_SERVER
		IS_TEST=true
		;;
    -T|--Types_excluded)
        shift
        EXCLUDE_ITYPES="$1"
        [ "$DEBUG" == true ] && logit "Excluding $EXCLUDE_ITYPES item types."
        ;;
    -v|--version)
        echo "$0 version: $VERSION"
        exit 0
        ;;
    -V|--VARS)
        SHOW_VARS=true
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
logit "== starting $0 version: $VERSION"
MSG="Loading data to "
if [ "$IS_TEST" == true ]; then
    DB_CMD="${DB_CMD}=${DB_DEV}"
    MSG="$MSG "`grep "database" $DB_DEV`
else
    DB_CMD="${DB_CMD}=${DB_PRODUCTION}"
    MSG="$MSG "`grep "database" $DB_PRODUCTION`
fi
[ "$SHOW_VARS" == true ] && show_vars
logit "$MSG"
logit "collecting data from the ILS."
scp $SSH_SERVER:$ILS_WORKING_DIR/$LASTCOPY_FILES $WORKING_DIR
collect_data
