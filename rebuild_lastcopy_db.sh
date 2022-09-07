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
# Goals: check for data, and if exists truncate tables in order and reload data.
#
. ~/.bashrc
APP=$(basename -s .sh $0)
HOME_DIR=/home/ils
WORKING_DIR=$HOME_DIR/last_copy
VERSION="1.00.01"
DB_PRODUCTION=$HOME_DIR/mysqlconfigs/lastcopy
DB_DEV=$HOME_DIR/mysqlconfigs/lastcopy_dev
DEBUG=false
LOG=$WORKING_DIR/lastcopy_driver.log
ALT_LOG=$WORKING_DIR/${APP}.log
DB_CMD="mysql --defaults-file"
IS_TEST=false
SERIES_SQL=$WORKING_DIR/series.sql
ITEMS_SQL=$WORKING_DIR/items.sql
TITLES_SQL=$WORKING_DIR/titles.sql
# List of all tables to truncate DO NOT change order or you will break referential integrity.
ALL_TABLES=("last_copy_series_titles" "last_copy_catkey_series_names" "last_copy_series" "last_copy_items" "last_copy_titles") 
####### Functions ########
# Display usage message.
# param:  none
# return: none
usage()
{
    cat << EOFU!
Usage: $0 [-option]
 Checks for sql files (see below) and if they exist and are not empty
 truncates the target last copy database (either production or test
 see --test for more information), then loads the data.

 -d, --debug: Turn on debugging messaging. Won't truncate tables
              but will report the command that would have been run.
 -h, --help: display usage message and exit.
 -t, --test: Perform on test database AKA staging.
 -v, --version: display application version and exit.
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

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "debug,help,test,version,xhelp" -o "dhtvx" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"
while true
do
    case $1 in
    -d|--debug)
        [ "$DEBUG" == true ] || logit "Turning on debugging"
		DEBUG=true
		;;
    -h|--help)
        usage
        exit 0
        ;;
    -t|--test)
        [ "$DEBUG" == true ] && logit "using test database"
		IS_TEST=true
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
logit "== starting $0 version: $VERSION"
[ -s "$SERIES_SQL" ] || logerr "Required file $SERIES_SQL missing or empty."
[ -s "$ITEMS_SQL" ] || logerr "Required file $ITEMS_SQL missing or empty."
[ -s "$TITLES_SQL" ] || logerr "Required file $TITLES_SQL missing or empty."
MSG="Loading data to "
if [ "$IS_TEST" == true ]; then
    DB_CMD="${DB_CMD}=${DB_DEV}"
    MSG="$MSG "`grep "database" $DB_DEV`
    ## Intentionally production because the test files are produced for accuracty.
    ## Ironically, once this is in production you can change it to:
else
    DB_CMD="${DB_CMD}=${DB_PRODUCTION}"
    MSG="$MSG "`grep "database" $DB_PRODUCTION`
fi
logit "$MSG"
# Truncate tables in this order.
# last_copy_series_titles
# last_copy_catkey_series_names
# last_copy_series
# last_copy_items
# last_copy_titles
## These don't need to be truncated, and don't have foreign key constraints.
## last_copy_complete_statuses
## last_copy_statuses
if [ "$DEBUG" == true ]; then
    for table_name in ${ALL_TABLES[@]}; do
        logit "DEBUG: $DB_CMD -e 'TRUNCATE TABLE $table_name;'"
    done
    logit "DEBUG: loading '$TITLES_SQL'"
    logit "DEBUG: loading '$ITEMS_SQL'"
    logit "DEBUG: loading '$SERIES_SQL'"
else
    for table_name in ${ALL_TABLES[@]}; do
        logit "truncating '$table_name'"
        $DB_CMD -e "TRUNCATE TABLE $table_name;" 2>>$ALT_LOG
    done
    # Now add new data
    logit "loading '$TITLES_SQL'"
    $DB_CMD <$TITLES_SQL
    logit "loading '$ITEMS_SQL'"
    $DB_CMD <$ITEMS_SQL
    logit "loading '$SERIES_SQL'"
    $DB_CMD <$SERIES_SQL
fi
logit "== done =="
exit 0
