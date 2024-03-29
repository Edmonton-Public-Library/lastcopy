#!usr/bin/env awk
# Version: 1.02.03 - Add today's date to all records.
## Create MySQL insert statements for items.
# Can be tested by the following instructions.
# 1) Create a file called 'test.data' with: 
#   echo -e "31221100061618|1000009|0|AUDIOBOOK|AUDBK|0|2021-12-15|2021-12-06|TEENNCOLL|YA|Easy readers A PBK|\n31221100997456|1000012|1|DISCARD|JBOOK|0|2022-03-02|2022-03-02|TEENVIDGME|ADULT|Easy readers A PBK|\n" > test.data
# 2) awk -f items.awk test.data
# 3) Check output:
# REPLACE INTO last_copy_items (id, last_copy_title_id, checkouts, current_location, item_type, copy_holds, last_active, last_charged, home_location, audience, call_number) VALUES 
# (2147483647,1000009,0,'AUDIOBOOK','AUDBK',0,'2021-12-15','2021-12-06','TEENNCOLL','YA','Easy readers A PBK','2024-02-21'),
# (2147483647,1000010,0,'DISCARD','AUDBK',0,'2021-12-15','2021-12-06','TEENNCOLL','YA','Easy readers A PBK','2024-02-21'),
# (2147483647,1000012,1,'STOLEN','JBOOK',0,'2022-03-02','2022-03-02','TEENVIDGME','ADULT','Easy readers A PBK','2024-02-21'),
# (2147483647,1000014,1,'AUDIOBOOK','JBOOK',0,'2022-03-02','2022-03-02','TEENVIDGME','ADULT','Easy readers A PBK','2024-02-21');
# COMMIT;
BEGIN {
    FS="|";
    # Added an empty field for 'notes' because the database doesn't allow empty values (yet)
    insertStatement = "REPLACE INTO last_copy_items (id, last_copy_title_id, checkouts, current_location, item_type, copy_holds, last_active, last_charged, home_location, audience, call_number, ils_updated_at) VALUES ";
    print insertStatement;
    count = -1;
    # The Test ILS seems to need smaller chunks.
    max_query_lines = 1500;
    default_date = "NULL";
    # Add today's date to all records.
    "date +\"%Y-%m-%d\"" | getline date;
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
    # 31221073208600|498521|7|DISCARD|JDVD21|1|2017-04-09|2017-04-03|PBK|ADULT|Easy readers A PBK|
    call_num = substr($11, 1, 25);
    printf "(%d,%d,%d,'%s','%s',%d,%s,%s,'%s','%s','%s','%s')",$1,$2,$3,$4,$5,$6,last_active,last_charged,$9,$10,call_num,date;
    if (count == -1){
        printf ",\n";
    }
    count++;
} 

END {
    print ";\nCOMMIT;";
}