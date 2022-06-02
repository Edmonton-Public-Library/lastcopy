#!usr/bin/env awk
# Version: 1.1.01
## Create MySQL insert statements for items.
BEGIN {
    FS="|";
    # id, last_copy_title_id, checkouts, current_location, item_type, copy_holds, last_active, last_charged
    # 31221069638372|451033|7|DISCARD|JDVD21|1|2017-04-09|2017-04-03|
    # 31221070218743|498461|20|DISCARD|JDVD21|1|2017-04-09|2017-04-03|
    # 31221073208600|498521|0|DISCARD|JDVD21|0|2017-04-09|2017-04-03|
    # Added an empty field for 'notes' because the database doesn't allow empty values (yet)

    insertStatement = "REPLACE INTO last_copy_items (id, last_copy_title_id, checkouts, current_location, item_type, copy_holds, last_active, last_charged) VALUES ";
    print insertStatement;
    count = -1;
    # The Test ILS seems to need smaller chunks.
    max_query_lines = 1500;
    default_date = "NULL";
}

# For any non-empty entry print the values to insert to the Items table.
/^[0-9]/ {
    if (count == max_query_lines) {
        count = 0;
        printf ";\nCOMMIT;\n" insertStatement "\n";
    } 
    if (count > 0){
        printf ",\n";
    }
    gsub(/[`,']/, "", $0);
    last_active = default_date;
    if ($7 == "" || $7 == "0"){
        last_active = default_date;
    } else {
        last_active = "'"$7"'";
    }
    
    if ($8 == "" || $8 == "0"){
        last_charged = default_date;
    } else {
        last_charged = "'"$8"'";
    }
    # id, last_copy_title_id, checkouts, current_location, item_type, copy_holds, last_active, last_charged
    # 31221073208600|498521|7|DISCARD|JDVD21|1|2017-04-09|2017-04-03|
    printf "(%d,%d,%d,'%s','%s',%d,%s,%s)",$1,$2,$3,$4,$5,$6,last_active,last_charged;
    if (count == -1){
        printf ",\n";
    }
    count++;
} 

END {
    print ";\nCOMMIT;";
}