#!usr/bin/env awk
# Version: 1.2 - Added error correction for empty title, author, and holds less than 0.
# Process title info into SQL for loading into appsng MySQL database.
BEGIN {
    FS="|";
    # 1000009|Victims [sound recording] : [an Alex Delaware novel] / Jonathan Kellerman|Kellerman, Jonathan|2012|0|a1000077|
    # 1000012|Story of the Titanic / illustration, Steve Noon ; consultant, Eric Kentley|Noon, Steve|2012|0|a1000033|
    # 1000028|The life and times of Benjamin Franklin [sound recording] / H.W. Brands|Brands, H. W.|2003|0|a1000099|
    # 1000031|Un hombre arrogante / Kim Lawrence|Lawrence, Kim|2011|0|a1000088|
    # 1000033|Noche de amor en Río / Jennie Lucas|Lucas, Jennie|2011|0|a1000034|
    insertStatement = "REPLACE INTO last_copy_titles (id, title, author, publication_year, title_holds, title_control_number) VALUES ";
    print insertStatement;
    count = -1;
    # The Test ILS seems to need smaller chunks.
    max_query_lines = 1500;
}


# For any non-empty entry print the values to insert to the Items table.
/^[0-9]/ {
    # Clean the line and test if there is a title and author.
    gsub(/['\\]/, "", $0);
    title = $2;
    author = $3;
    # Some titles don't have titles (??). That should be the minimal criteria for a title!
    if (title != "" && author != "") {
        if (count == max_query_lines) {
            count = 0;
            printf ";\nCOMMIT;\n" insertStatement "\n";
        }
        # Print a new line if we intend on continuing to process the line.
        if (count > 0){
            printf ",\n";
        }
        # Crude form of truncating to fit varchar(255)
        if (length(title) > 255) {
            title = sprintf("%s...", substr(title, 0, 251));
        }
        if (length(author) > 255) {
            author = sprintf("%s...", substr(author, 0, 251));
        }
        # Other processes will put a default '-1' holds which has to be fixed here.
        title_holds = $5;
        if (title_holds < 0) {
            title_holds = 0;
        }
        # Some items don't have publication years so output a null value.
        publication_year = $4;
        if (publication_year <= 0) {
            printf "(%d, '%s', '%s', NULL, %d, '%s')",$1,title,author,title_holds,$6;
        } else {
            printf "(%d, '%s', '%s', %d, %d, '%s')",$1,title,author,publication_year,title_holds,$6;
        }
        # Only update the counts that are actually intended to be loaded.
        if (count == -1){
            printf ",\n";
        }
        count++;
    }
} 

END {
    print ";\nCOMMIT;";
}