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
WORKING_DIR=/software/EDPL/Unicorn/EPLwork/anisbet/Discards/Test
VERSION="0.06.04"
DB_PRODUCTION=appsng
DB_DEV=appsng_dev
HICIRC_CKEY_LIST=$WORKING_DIR/highcirctitles.lst
MIN_CHARGES=20
DEBUG=false
DEV=false
LOCAL=false
LOG=$WORKING_DIR/lastcopy.log
LAST_RUN=$WORKING_DIR/last.run
DB_CMD="mysql --defaults-file=~/mysqlconfigs/lastcopy_dev"
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

  The database is automatically rebuilt if it is more than a day old.

  -c, --charges={n} sets the minimum charges all items on a title must have to make the grubby list.
  -d, --debug turn on debug logging.
  -D, --dev: create and use dev version of database.
  -h, --help: display usage message and exit.
  -l, --local: create sqlite3 database rather than use MySQL server.
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
# Logs messages as an error and exits with status code '1'.
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


create_db()
{
	# Create the database
    logit "creating database"
    [ $DEBUG == true ] && logit "\$DB_CMD='$DB_CMD'"
    if [ "$LOCAL" == true ]; then
        ### sqlite3 version
        $DB_CMD <<END_SQL
CREATE TABLE IF NOT EXISTS catalog_items (
    id INT PRIMARY KEY,
    catalog_title_id INT,
    call_number INT, 
    copy_number INT, 
    checkouts INT, 
    current_location TEXT, 
    item_type TEXT, 
    copy_holds INT, 
    title_holds INT, 
    last_active TEXT, 
    last_charged TEXT
);
END_SQL
    else
        ### MySQL version.
        $DB_CMD <<END_SQL
CREATE TABLE IF NOT EXISTS catalog_items (
    id INT PRIMARY KEY, -- barcode
    catalog_title_id INT,
    call_number INT,
    copy_number INT,
    checkouts INT,
    current_location VARCHAR (25),
    item_type VARCHAR (25),
    copy_holds INT,
    title_holds INT,
    last_active DATE,
    last_charged DATE,
    FOREIGN KEY (catalog_title_id)
        REFERENCES catalog_titles (id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
);
END_SQL
    fi
    logit "create database command exiting."
}


# Produces cat keys whose items have more than $MIN_CHARGES 
collect_item_info()
{
    ## Clean up any pre-existing database if it is more than a day old.
    if [ -f "$LAST_RUN" ]; then
        local yesterday=$(date -d 'now - 1 days' +%s)
        local db_age=$(date -r "$LAST_RUN" +%s)
        if (( db_age <= yesterday )); then
            # Truncate the tables - either local or mysql
            rm $LAST_RUN
            touch $LAST_RUN
            echo "TRUNCATE TABLE catalog_items;" | $DB_CMD
        else
            # keep fresh database.
            logit "database is less than a day old, nothing to do."
            return
        fi
    fi
    # Name of the scratch SQL insert commands.
    local sql=$WORKING_DIR/items.sql
    
	# Select all items but do it from the cat keys because selitem 
	# reports items with seq. and copy numbers that don't exist.
	# To fix that select all the titles, then ask selitem to output
	# all the items on the title.
	logit "creating SQL from catalog selection"
    [ -s "$WORKING_DIR/items.awk" ] || logerr "$WORKING_DIR/items.awk required but missing"
	selcatalog -oCh 2>/dev/null | selitem -iC -oIdmthSanB 2>/dev/null | awk -f $WORKING_DIR/items.awk >$sql 
    [ -s "$sql" ] || logerr "no sql statements were generated."
    logit "loading data"
    cat $sql | $DB_CMD
    # [ -s "$sql" ] && rm $sql
    logit "adding indexes."
    echo "CREATE INDEX IF NOT EXISTS idx_ckey ON catalog_items (catalog_title_id);" | $DB_CMD
    echo "CREATE INDEX IF NOT EXISTS idx_ckey_callnum ON catalog_items (catalog_title_id, call_number);" | $DB_CMD
    echo "CREATE INDEX IF NOT EXISTS idx_itype ON catalog_items (item_type);" | $DB_CMD
    echo "CREATE INDEX IF NOT EXISTS idx_cloc ON catalog_items (current_location);" | $DB_CMD
    echo "CREATE INDEX IF NOT EXISTS idx_lactive ON catalog_items (last_active);" | $DB_CMD
    echo "CREATE INDEX IF NOT EXISTS idx_lcharged ON catalog_items (last_charged);" | $DB_CMD
    echo "CREATE INDEX IF NOT EXISTS idx_id ON catalog_items (id);" | $DB_CMD
    logit "indexing complete"
}

### End of function declarations

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "charges:,debug,dev,help,local,version,xhelp" -o "c:dDhlvx" -a -- "$@")
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
        logit "compile cat keys where all items have $1 minimum charges"
		MIN_CHARGES=$1
		;;
    -d|--debug)
        logit "turning on debugging"
		DEBUG=true
		;;
    -D|--dev)
        logit "dev mode"
		DEV=true
		;;
    -h|--help)
        usage
        exit 0
        ;;
    -l|--local)
        logit "create and use local sqlite3 database."
		LOCAL=true
        # Which database method are we using local or mysql
        DB_CMD="sqlite3 $WORKING_DIR/$DB_DEV"
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
logit "testing freshness of item information"
create_db
collect_item_info
# Find all the cat keys who's items all have more than $MIN_CHARGES charges.
[ $DEBUG == true ] && logit "starting selection query"
echo "SELECT catalog_title_id FROM catalog_items GROUP BY catalog_title_id HAVING min(checkouts) >= $MIN_CHARGES;" | $DB_CMD >$HICIRC_CKEY_LIST
[ -s "$HICIRC_CKEY_LIST" ] || logit "no titles matched criteria of all copies having more than $MIN_CHARGES."
[ $DEBUG == true ] && logit "done"
logit "hi-circ list $HICIRC_CKEY_LIST created"
logit "== done =="
exit 0
# EOF
