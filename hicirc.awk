#!usr/bin/env awk

## Create sql insert statements for hicirc counts on titles.
BEGIN {
    FS="|";
    insertStatement = "INSERT OR IGNORE INTO Items (ckey, callnum, cpnum, total, cloc, itype, cholds, tholds) VALUES ";
    print "BEGIN TRANSACTION;"
    print insertStatement;
    count = -1;
    # The Test ILS seems to need smaller chunks.
    max_query_lines = 150;
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
    # ckey,total charges
    printf "(%d, %d, %d, %d,'%s','%s', %d, %d)",$1,$2,$3,$4,$5,$6,$7,$8;
    if (count == -1){
        printf ",\n";
    }
    count++;
} 

END {
    print ";";
    print "END TRANSACTION;";
}