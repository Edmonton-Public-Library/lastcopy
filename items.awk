#!usr/bin/env awk

## Create sql insert statements for hicirc counts on titles.
BEGIN {
    FS="|";
    # CKey, ShelfKey, CurrLoc, Type, LActive, LCharged, BCode, Charges, CHolds
    # 548305|DVD J SER LEM|STOLEN|JDVD21|20091120|20091120|31221092798581  |16|0|
    insertStatement = "INSERT OR IGNORE INTO items (CKey, ShelfKey, CurrLoc, IType, LActive, LCharged, BCode, Charges, CHolds) VALUES ";
    print "BEGIN TRANSACTION;"
    print insertStatement;
    count = -1;
    # The Test ILS seems to need smaller chunks.
    max_query_lines = 150;
    default_date = "1900-01-01";
}


# For any non-empty entry print the values to insert to the Items table.
/^[0-9]/ {
    if (count == max_query_lines) {
        count = 0;
        printf ";\nEND TRANSACTION;\nBEGIN TRANSACTION;\n" insertStatement "\n";
    } 
    if (count > 0){
        printf ",\n";
    }
    
    last_active = default_date;
    if (length($5) == 8){
        # Format the date into a ISO standard date: YYYY-MM-DD.
        year = substr($5,1,4);
        month= substr($5,5,2);
        day  = substr($5,7);
        last_active = sprintf("%d-%02d-%02d",year,month,day);
    }
    last_charged = default_date;
    if (length($6) == 8){
        # Format the date into a ISO standard date: YYYY-MM-DD.
        year = substr($6,1,4);
        month= substr($6,5,2);
        day  = substr($6,7);
        last_charged = sprintf("%d-%02d-%02d",year,month,day);
    }
    gsub(/[`,]/, "", $0);
    ## Get rid of the trailing space in bar codes.
    gsub(/[ ]+$/, "", $7);
    # CKey, ShelfKey, CurrLoc, Type, LActive, LCharged, BCode, Charges, CHolds
    # 548305|DVD J SER LEM|STOLEN|JDVD21|20091120|20091120|31221092798581  |16|0|
    printf "(%d,'%s','%s','%s','%s','%s',%d,%d,%d)",$1,$2,$3,$4,last_active,last_charged,$7,$8,$9;
    if (count == -1){
        printf ",\n";
    }
    count++;
} 

END {
    print ";";
    print "END TRANSACTION;";
}