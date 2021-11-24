#!usr/bin/env awk

## Create sql insert statements for hicirc counts on titles.
BEGIN {
    FS="|";
    insertStatement = "INSERT OR IGNORE INTO Items (ckey, callnum, cpnum, ckos, cloc, itype, cholds, tholds, lactive, lcharged) VALUES ";
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
    if (length($9) == 8){
        # Format the date into a ISO standard date: YYYY-MM-DD.
        year = substr($9,1,4);
        month= substr($9,5,2);
        day  = substr($9,7);
        last_active = sprintf("%d-%d-%d",year,month,day);
    }
    last_charged = default_date;
    if (length($10) == 8){
        # Format the date into a ISO standard date: YYYY-MM-DD.
        year = substr($10,1,4);
        month= substr($10,5,2);
        day  = substr($10,7);
        last_charged = sprintf("%d-%d-%d",year,month,day);
    }

    # ckey,ckos - total charges
    printf "(%d, %d, %d, %d,'%s','%s', %d, %d, '%s','%s')",$1,$2,$3,$4,$5,$6,$7,$8,last_active,last_charged;
    if (count == -1){
        printf ",\n";
    }
    count++;
} 

END {
    print ";";
    print "END TRANSACTION;";
}