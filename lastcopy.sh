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
# Goals are to collect all the data necessary to fill the tables in 
# the last copy database on epl-mysql.epl.ca.
#
# The data collected matches the following.
#
# 1) Title with zero or one circulatable items.
# 2) All the items on a title with a high number of circs, where 'high number' is configurable.
# 3) Series information if available, collected from the 490 and 830 tags.
#
# Locations that are not circulatable are as follows. 
# UNKNOWN, MISSING, LOST, DISCARD, LOST-PAID, LONGOVRDUE,
# CANC_ORDER, INCOMPLETE, DAMAGE, BARCGRAVE, NON-ORDER,
# LOST-ASSUM, LOST-CLAIM, STOLEN, NOF
#
# Environment setup required by cron to run script because its daemon runs
# without assuming any environment settings and we need to use sirsi's.
#######################################################################
# ***           Edit these to suit your environment               *** #
. /software/EDPL/Unicorn/EPLwork/cronjobscripts/setscriptenvironment.sh
###############################################################################
## TODO: Continue refactoring to match requirements above.
WORKING_DIR=/software/EDPL/Unicorn/EPLwork/anisbet/Discards/Test
VERSION="0.02.02_DEV"
DB_PRODUCTION=appsng
DB_DEV=appsng_dev
HICIRC_CKEY_LIST=$WORKING_DIR/highcirctitles.lst
MIN_CHARGES=20
DEBUG=false
LOG=$WORKING_DIR/lastcopy.log
DB=$WORKING_DIR/lastcopy.db
DB_CMD="sqlite3 $DB"
ITEMS_AWK=$WORKING_DIR/items.awk
TITLES_AWK=$WORKING_DIR/titles.awk
###############################################################################
# Display usage message.
# param:  none
# return: none
usage()
{
    cat << EOFU!
Usage: $0 [-option]
 Application to collect data for last copy.

 Database schema:
 CREATE TABLE IF NOT EXISTS items (
    CKey INT,
    ShelfKey TEXT,
    CurrLoc TEXT,
    IType TEXT,
    LActive TEXT,
    LCharged TEXT,
    BCode INT PRIMARY KEY,
    Charges INT,
    CHolds INT
);
CREATE TABLE IF NOT EXISTS titles (
    CKey INT PRIMARY KEY,
    TCN TEXT,
    Author TEXT,
    Title TEXT,
    PubYear INT,
    Series TEXT,
    THolds INT
);

 -c, --charges={n} sets the minimum charges all items on a title must have to make the grubby list.
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
    echo "\$DB_PRODUCTION=$DB_PRODUCTION"
    echo "\$DB_DEV=$DB_DEV"
    echo "\$HICIRC_CKEY_LIST=$HICIRC_CKEY_LIST"
    echo "\$MIN_CHARGES=$MIN_CHARGES"
    echo "\$DEBUG=$DEBUG"
    echo "\$LOG=$LOG"
    echo "\$DB=$DB"
    echo "\$DB_CMD=$DB_CMD"
    echo "\$ITEMS_AWK=$ITEMS_AWK"
    echo "\$TITLES_AWK=$TITLES_AWK"
}

# Produces cat keys whose items have more than $MIN_CHARGES 
collect_item_info()
{
    ## Clean up any pre-existing database if it is more than a day old.
    if [ -s "$DB" ]; then
        local yesterday=$(date -d 'now - 1 days' +%s)
        local db_age=$(date -r "$DB" +%s)
        if (( db_age <= yesterday )); then
            # Truncate the tables - either local or mysql
            rm $DB
            create_db
        else
            # keep fresh database.
            logit "database is less than a day old, nothing to do."
            return
        fi
    else
        create_db
    fi
    # Output file for the selcatalog and selitem commands.
    local sql=$WORKING_DIR/items.sql
    [ -s "$ITEMS_AWK" ] || logerr "missing required $ITEMS_AWK script"
    [ -s "$TITLES_AWK" ] || logerr "missing required $TITLES_AWK script"
	logit "collecting item info"
    ## Selcatalog-in: *
    ## selcatalog-out: ckey,title_holds
    ## selitem-in: ckey
    ## selitem-out: callNumKey,currLoc,type,lastActive,lastCharged,barCode,totalCharges,copyHolds
    ## selcallnum-in: callNumKey
    ## selcallnum-out: ckey,shelvingKey,[currLoc,type,lastActive,lastCharged,barCode,totalCharges,copyHolds]
    ## 548305|DVD J SER LEM|STOLEN|JDVD21|20091120|20091120|31221092798581  |16|0|
    ## 548305|DVD J SER LEM|CHECKEDOUT|JDVD21|20220323|20220323|31221113074103  |38|0|
    ## 548305|DVD J SER LEM|JUVMOVIE|JDVD21|20210901|20210831|31221102754715  |77|0|
    ## 548305|DVD J SER LEM|LOST-ASSUM|JDVD21|20150324|20150201|31221106513737  |49|0|
    ## 548305|DVD J SER LEM|LOST-ASSUM|JDVD21|20151224|20151103|31221106513810  |69|0|
    ## 548305|DVD J SER LEM|LOST-ASSUM|JDVD21|20180307|20180115|31221113074046  |15|0|
    ## 548305|DVD J SER LEM|JUVMOVIE|JDVD21|20211229|20211223|31221113074160  |49|0|
    ## 548305|DVD J SER LEM|LOST-ASSUM|JDVD21|20180302|20160706|31221106513802  |72|0|
    ## 548305|DVD J SER LEM|LOST-ASSUM|JDVD21|20180416|20180211|31221113074178  |24|0|
    ## 548305|DVD J SER LEM|LOST-ASSUM|JDVD21|20180627|20180507|31221102753907  |55|0|
    ## 548305|DVD J SER LEM|JUVMOVIE|JDVD21|20211121|20211120|31221113074038  |46|0|
    ## 548305|DVD J SER LEM|JUVMOVIE|JDVD21|20210429|20210425|31221113074087  |53|0|
    ## 548305|DVD J SER LEM|JUVMOVIE|JDVD21|20210706|20210703|31221113074061  |50|0|
    ## 548305|DVD J SER LEM|JUVMOVIE|JDVD21|20211020|20211014|31221113074020  |50|0|
    ## 548305|DVD J SER LEM|JUVMOVIE|JDVD21|20211129|20211104|31221113074004  |54|0|
    local cat_data=$WORKING_DIR/cat_records.lst
    # The second translate takes care of possesive plural nouns in call numbers.
	selcatalog -oCFatve -e380,490 2>/dev/null | tr -d \''"`\' |  tee $cat_data | selitem -iC -oNmtanBdh 2>/dev/null | selcallnum -iN -oCDS 2>/dev/null | tr -d \''"`\' | awk -f $ITEMS_AWK >$sql
    [  -s "$sql" ] || logerr "no item output generated."
    if [ "$DEBUG" == true ]; then
        local item_count=$(grep -e "^(" $sql | wc -l)
        logit "DEBUG: adding $item_count items to the database."
    fi
    cat $sql | $DB_CMD
    [ -f "$sql" ] && [ "$DEBUG" == false ] && rm $sql
    logit "creating title info"
    sql=$WORKING_DIR/titles.sql
    ## cat key|Author|Title|Publication year.
    # 2471515|LSC4480726    |Levy, Ganit|What Should Danny Do: School Day / by Ganit  Levy|2022|-|Power to Choose|
    logit "collecting hold data"
    # 23|2471515|LSC4480726    |Levy, Ganit|What Should Danny Do: School Day / by Ganit  Levy|2022|-|Power to Choose|123456|
    ## Gather all the active holds for the titles, dedup and count them.
    cat $cat_data | selhold -iC -jACTIVE -oCSU 2>/dev/null | pipe.pl -dc0 -A -P | pipe.pl -oc1,c2,c3,c4,c5,c6,c7,c0 -P >${cat_data}.holds
    ## Since zero holds are not output we make a new list of all titles with no holds and merge the holds file with pipe.pl.
    cat $cat_data | pipe.pl -m 'c6:@|0|' >${cat_data}.zero_holds
    cat ${cat_data}.zero_holds | pipe.pl -0 ${cat_data}.holds -M 'c0:c0?c7.0' -oc7,exclude | awk -f $TITLES_AWK >$sql 
    [ -s "$sql" ] || logerr "no title data were generated." 
    if [ "$DEBUG" == true ]; then
        local title_count=$(grep -e "^(" $sql | wc -l)
        logit "DEBUG: adding $title_count titles to the database."
    else
        rm $cat_data ${cat_data}.holds ${cat_data}.zero_holds
    fi
    logit "starting to load title data"
    cat $sql | $DB_CMD
    [ -f "$sql" ] && [ "$DEBUG" == false ] && rm $sql
    logit "adding item indexes."
    echo "CREATE INDEX IF NOT EXISTS idx_ckey ON items (CKey);" | $DB_CMD
    echo "CREATE INDEX IF NOT EXISTS idx_bcode ON items (BCode);" | $DB_CMD
    logit "adding title indexes."
    echo "CREATE INDEX IF NOT EXISTS idx_ckey ON titles (CKey);" | $DB_CMD
    echo "CREATE INDEX IF NOT EXISTS idx_series ON titles (Series);" | $DB_CMD
    logit "indexing complete"
}

create_db()
{
    # Create the database
    logit "creating database"
    # Items table
    # CKey, ShelfKey, CurrLoc, Type, LActive, LCharged, BCode, Charges, CHolds
    # Titles table
    # CKey, TCN, Author, Title, PubYear, Series
    $DB_CMD <<END_SQL
CREATE TABLE IF NOT EXISTS items (
    CKey INT,
    ShelfKey TEXT,
    CurrLoc TEXT,
    IType TEXT,
    LActive TEXT,
    LCharged TEXT,
    BCode INT PRIMARY KEY,
    Charges INT,
    CHolds INT
);
CREATE TABLE IF NOT EXISTS titles (
    CKey INT PRIMARY KEY,
    TCN TEXT,
    Author TEXT,
    Title TEXT,
    PubYear INT,
    Series TEXT,
    THolds INT
);
END_SQL
}

### End of function declarations

### Check input parameters.
# $@ is all command line parameters passed to the script.
# -o is for short options like -v
# -l is for long options with double dash like --version
# the comma separates different long options
# -a is for long options with single dash like -version
options=$(getopt -l "charges:,debug,help,version,VARS,xhelp" -o "c:dhvVx" -a -- "$@")
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
logit "== starting $0 version: $VERSION"
logit "testing freshness of item information"
collect_item_info
# Find all the cat keys who's items all have more than $MIN_CHARGES charges.
[ $DEBUG == true ] && logit "starting selection query"
echo "SELECT CKey FROM items GROUP BY CKey HAVING min(Charges) >= $MIN_CHARGES;" | $DB_CMD >$HICIRC_CKEY_LIST
[ -s "$HICIRC_CKEY_LIST" ] || logit "no titles matched criteria of all copies having more than $MIN_CHARGES."
[ $DEBUG == true ] && logit "done"
logit "hi-circ list $HICIRC_CKEY_LIST created"
logit "== done =="
exit 0
# EOF
