#!usr/bin/env awk

# Process title info into SQL for loading into appsng MySQL database.
BEGIN {
    FS="|";
    # 1000009|Victims [sound recording] : [an Alex Delaware novel] / Jonathan Kellerman|Kellerman, Jonathan|2012|0|
    # 1000012|Story of the Titanic / illustration, Steve Noon ; consultant, Eric Kentley|Noon, Steve|2012|0|
    # 1000028|The life and times of Benjamin Franklin [sound recording] / H.W. Brands|Brands, H. W.|2003|0|
    # 1000031|Un hombre arrogante / Kim Lawrence|Lawrence, Kim|2011|0|
    # 1000033|Noche de amor en Río / Jennie Lucas|Lucas, Jennie|2011|0|
    insertStatement = "REPLACE INTO last_copy_titles (id, title, author, publication_year, title_holds) VALUES ";
    print insertStatement;
    count = -1;
    # The Test ILS seems to need smaller chunks.
    max_query_lines = 1500;
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
    gsub(/['\\]/, "", $0);
    title = $2;
    if (length(title) > 255) {
        title = sprintf("%s...", substr(title, 0, 251));
    }
    author = $3;
    if (length(author) > 255) {
        author = sprintf("%s...", substr(author, 0, 251));
    }
    printf "(%d, '%s', '%s', %d, %d)",$1,title,author,$4,$5;
    if (count == -1){
        printf ",\n";
    }
    count++;
} 

END {
    print ";\nCOMMIT;";
}