#!usr/bin/env awk
# Version: 1.0
## Create sql insert statements for series data.
BEGIN {
    FS="|";
    # CKey, Series
    # 691|North of 52 Collection|
    # 715|North of 52 Collection|
    # 723|Heritage Collection|
    insertStatement = "REPLACE INTO last_copy_series (id, name) VALUES ";
    print insertStatement;
    count = -1;
    max_query_lines = 1500;
}


# For any non-empty entry print the values to insert to the series table.
/^[0-9]/ {
    if (count == max_query_lines) {
        count = 0;
        printf ";\nCOMMIT;\n" insertStatement "\n";
    } 
    if (count > 0){
        printf ",\n";
    }
    
    # CKey, Series
    # 548305|North of 54|
    # Added an empty field for 'description' because the database doesn't allow empty values (yet)
    printf "(%d,'%s')",$1, $2;
    if (count == -1){
        printf ",\n";
    }
    count++;
} 

END {
    print ";\nCOMMIT;";
}