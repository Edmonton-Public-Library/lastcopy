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
VERSION="0.00.00_DEV"
DB_PRODUCTION=$HOME_DIR/mysqlconfigs/lastcopy
DB_DEV=$HOME_DIR/mysqlconfigs/lastcopy_dev
DEBUG=false
LOG=$WORKING_DIR/lastcopy_driver.log
DB_CMD="mysql --defaults-file"
IS_TEST=false
###############################################################################
# Display usage message.
# param:  none
# return: none
usage()
{
    cat << EOFU!
Usage: $0 [-option]
 Application to collect data for last copy.


 -c, --collect_data Gets the latest data from the ILS.
 -d, --debug turn on debug logging.
 -h, --help: display usage message and exit.
 -t, --test: Load data into the test database; $DB_DEV
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
}

collect_data()
{
    logerr "TODO: implement this function."
    ## TODO: Set criteria and create queries for sqlite3 database.
    ## TODO: (Batch) import data into the mysql database.
}

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "collect_data:,debug,help,test,version,VARS,xhelp" -o "cdhtvVx" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"
while true
do
    case $1 in
    -c|--collect_data)
        logit "collecting data from the ILS."
		;;
    -d|--debug)
        logit "turning on debugging"
		DEBUG=true
		;;
    -h|--help)
        usage
        exit 0
        ;;
    -t|--test)
        logit "using test database"
		IS_TEST=true
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
logit "== starting $0 version: $VERSION"
MSG="Loading data to "
if [ "$IS_TEST" == true ]; then
    DB_CMD="${DB_CMD}=${DB_DEV}"
    MSG="$MSG "`grep "database" $DB_DEV`
else
    DB_CMD="${DB_CMD}=${DB_PRODUCTION}"
    MSG="$MSG "`grep "database" $DB_PRODUCTION`
fi
logit "$MSG"
logit "testing freshness of item information"
[ $DEBUG == true ] && logit "collecting data from the ILS."
collect_data
