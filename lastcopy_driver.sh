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
VERSION="1.02.02"
DB_PRODUCTION=$HOME_DIR/mysqlconfigs/lastcopy
DB_DEV=$HOME_DIR/mysqlconfigs/lastcopy_dev
ILS_WORKING_DIR=/software/EDPL/Unicorn/EPLwork/cronjobscripts/LastCopy
LASTCOPY_FILES="*.table"
DEBUG=false
LOG=$WORKING_DIR/lastcopy_driver.log
DB_CMD="mysql --defaults-file"
IS_TEST=false
# These locations put a title at risk of not having circulatable copies.
# Don't select titles where all the items on a title have these locations.
EXCLUDE_LOCATIONS="INTERNET,HOME"
# Don't select titles where all the items on a title have these item types.
EXCLUDE_ITYPES="ILL-BOOK,E-RESOURCE"
PRODUCTION_ILS='sirsi@edpl.sirsidynix.net'
TEST_ILS='sirsi@edpltest.sirsidynix.net'
SSH_SERVER=$PRODUCTION_ILS
SERIES_AWK="$WORKING_DIR/bin/series.awk"
ITEMS_AWK="$WORKING_DIR/bin/items.awk"
TITLES_AWK="$WORKING_DIR/bin/titles.awk"
RUN_TABLE_COMPILER="$ILS_WORKING_DIR/lastcopy_compiler.sh"
SHOW_VARS=false
COMPILE_FRESH_TABLES=false
###############################################################################
# Display usage message.
# param:  none
# return: none
usage()
{
    cat << EOFU!
Usage: $0 [-options]
 Fetches last copy data from the ILS compiles it into SQL statements
 and loads it into production appsng database by default, or appsng_dev
 if --test is used.

 When fetching files, they are SCP'd from either production or test ILS,
 and then compiled into SQL statements. If the local files are less than
 an hour old they are used, and fresh ones copied over otherwise.

 -c, --compile Compile fresh table files on the ILS. Takes more time.
   If the existing files in $WORKING_DIR are still fresh this option 
   is ignored.
 -d, --debug turn on debug logging.
 -h, --help: display usage message and exit.
 -t, --test: Load data into the appsng test database.
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
    echo "\$COMPILE_FRESH_TABLES=$COMPILE_FRESH_TABLES"
    echo "\$RUN_TABLE_COMPILER=$RUN_TABLE_COMPILER"
    echo "\$SSH_SERVER=$SSH_SERVER"
    echo "\$SERIES_AWK=$SERIES_AWK"
    echo "\$ITEMS_AWK=$ITEMS_AWK"
    echo "\$TITLES_AWK=$TITLES_AWK"
}

# Builds the queries to collect the data from the remote temp database.
collect_data()
{
    # local appsng_titles="last_copy_titles.table"
    # local appsng_items="last_copy_items.table"
    # local appsng_series="last_copy_series.table"
    local appsng_titles="$WORKING_DIR/last_copy_titles.table"
    local appsng_items="$WORKING_DIR/last_copy_items.table"
    local appsng_series="$WORKING_DIR/last_copy_series.table"
    ## Figure out what data we need, collect it from the lastcopy, grubby, and series
    ## lst files on the ILS.
    if [ -s "$appsng_items" ]; then
        local an_hour_ago=$(date -d 'now - 1 hours' +%s)
        local src_file_age=$(date -r "$appsng_items" +%s)
        if (( $src_file_age <= $an_hour_ago )); then
            logit "copying data from the ILS."
            if [ "$COMPILE_FRESH_TABLES" == true ]; then
                if ! ssh $SSH_SERVER "$RUN_TABLE_COMPILER"; then
                    logerr "compile requested but failed to run the table compiler on the ITS. Check $RUN_TABLE_COMPILER"
                fi
            fi
            if ! scp $SSH_SERVER:$ILS_WORKING_DIR/$LASTCOPY_FILES $WORKING_DIR ; then
                logerr "scp command $SSH_SERVER:$ILS_WORKING_DIR/$LASTCOPY_FILES $WORKING_DIR failed!"
            fi
        else
            logit "the existing files are less than an hour old, using them."
        fi
    else
        if ! scp $SSH_SERVER:$ILS_WORKING_DIR/$LASTCOPY_FILES $WORKING_DIR ; then
            logerr "scp command $SSH_SERVER:$ILS_WORKING_DIR/$LASTCOPY_FILES $WORKING_DIR failed!"
        fi
    fi
    [ -s "$appsng_titles" ] || logerr "$appsng_titles are missing or empty."
    [ -s "$appsng_items" ] || logerr "$appsng_items are missing or empty."
    [ -s "$appsng_series" ] || logerr "$appsng_series are missing or empty."

    local titles_sql="$WORKING_DIR/titles.sql"
    local items__sql="$WORKING_DIR/items.sql"
    local series_sql="$WORKING_DIR/series.sql"
    ## Remove the old sql statements you should have reviewed them before now.
    [ -s "$titles_sql" ] && rm $titles_sql
    [ -s "$items__sql" ] && rm $items__sql
    [ -s "$series_sql" ] && rm $series_sql
    logit "compiling titles sql statements"
    awk -f $TITLES_AWK $appsng_titles >$titles_sql
    ## Parse items into SQL statements.
    # 31221100061618|1000009|0|AUDIOBOOK|AUDBK|0|2021-12-15|2021-12-06|
    # 31221100997456|1000012|1|DISCARD|JBOOK|0|2022-03-02|2022-03-02|
    logit "compiling items sql statements"
    awk -f $ITEMS_AWK $appsng_items >$items__sql
    ## Parse series into SQL statements.
    logit "compiling series sql statements"
    awk -f $SERIES_AWK $appsng_series >$series_sql
    ## **This one must be the first to load **.
    logit "starting to load $titles_sql:"
    $DB_CMD <$titles_sql #2>>$LOG
    logit "starting to load $items__sql:"
    $DB_CMD <$items__sql #2>>$LOG
    logit "starting to load $series_sql:"
    $DB_CMD <$series_sql #2>>$LOG
}

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "compile,debug,help,test,version,VARS,xhelp" -o "cdhtvVx" -a -- "$@")
if [ $? != 0 ] ; then echo "Failed to parse options...exiting." >&2 ; exit 1 ; fi
# set --:
# If no arguments follow this option, then the positional parameters are unset. Otherwise, the positional parameters
# are set to the arguments, even if some of them begin with a ‘-’.
eval set -- "$options"
while true
do
    case $1 in
    -c|--compile)
        [ "$DEBUG" == true ] || logit "Compiling fresh table files"
		COMPILE_FRESH_TABLES=true
		;;
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
        SSH_SERVER=$TEST_SERVER
		IS_TEST=true
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
[ -s "$SERIES_AWK" ] || logerr "Required file $SERIES_AWK missing or empty."
[ -s "$ITEMS_AWK" ] || logerr "Required file $ITEMS_AWK missing or empty."
[ -s "$TITLES_AWK" ] || logerr "Required file $TITLES_AWK missing or empty."
MSG="Loading data to "
if [ "$IS_TEST" == true ]; then
    DB_CMD="${DB_CMD}=${DB_DEV}"
    MSG="$MSG "`grep "database" $DB_DEV`
    ## Intentionally production because the test files are produced for accuracty.
    ## Ironically, once this is in production you can change it to:
    # SSH_SERVER=$TEST_ILS
    SSH_SERVER=$PRODUCTION_ILS
else
    DB_CMD="${DB_CMD}=${DB_PRODUCTION}"
    MSG="$MSG "`grep "database" $DB_PRODUCTION`
    SSH_SERVER=$PRODUCTION_ILS
fi
[ "$SHOW_VARS" == true ] && show_vars
logit "$MSG"
collect_data
logit "== done =="
exit 0
