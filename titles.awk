#!usr/bin/env awk

## Create sql insert statements for hicirc counts on titles.
#     id INT PRIMARY KEY NOT NULL, -- This is the cat key
#     tcn VARCHAR (64) NOT NULL,
#     author VARCHAR (125),
#     title VARCHAR (255),
#     publication_year INT,
#     t_380 VARCHAR (64),
#     t_490 VARCHAR (64)
BEGIN {
    FS="|";
    insertStatement = "INSERT OR IGNORE INTO catalog_titles (id, tcn, author, title, publication_year, t_380, t_490) VALUES ";
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
    t_380 = $6;
    gsub(/["'`,]/, "", t_380);
    if (t_380 !~ /[0-9]/) {
        t_380 = "-";
    }
    t_490 = $7
    gsub(/["'`,]/, "", t_490);
    if (t_490 !~ /[0-9]/) {
        t_490 = "-";
    }
    
    printf "(%d, '%s', '%s', '%s', %d, '%s', '%s')",$1,$2,$3,$4,$5,$6,$7;
    if (count == -1){
        printf ",\n";
    }
    count++;
} 

END {
    print ";";
    print "END TRANSACTION;";
}