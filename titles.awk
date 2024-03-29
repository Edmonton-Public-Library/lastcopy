#!usr/bin/env awk
# Version: 2.03.01 - Added today's date to titles.
# Process title info into SQL for loading into appsng MySQL database.
BEGIN {
    FS="|";
    # 1000044|Caterpillar to butterfly / Laura Marsh|Marsh, Laura F.|2012|1|epl000001934|-|E MAR|
    # 1000044|Caterpillar to butterfly / Laura Marsh|Marsh, Laura F.|2012|1|epl000001934|-|E MAR|n|
    # @TODO: The column for fiction is TO BE DETERMINED!!! Change before deploying.
    insertStatement = "REPLACE INTO last_copy_titles (id, title, author, publication_year, title_holds, title_control_number, call_number, is_fiction, ils_updated_at) VALUES ";
    print insertStatement;
    count = -1;
    # The Test ILS seems to need smaller chunks.
    max_query_lines = 1500;
    # Add today's date to all records.
    "date +\"%Y-%m-%d\"" | getline date;
}


# For any non-empty entry print the values to insert to the Items table.
/^[0-9]/ {
    # Clean the line and test if there is a title and author.
    gsub(/['\\]/, "", $0);
    title = $2;
    author = $3;
    # Some titles don't have titles (??). That should be the minimal criteria for a title!
    if (title != "" && author != "" && ! match(title, /(\[electronic resource\])/) && ! match(title, /(ILL ?- ?)/)) {
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
        # Call number has been added ($7, or $8) so process it here
        # 1000044|Caterpillar to butterfly / Laura Marsh|Marsh, Laura F.|2012|1|epl000001934|-|E MAR|
        call_num = $7;
        fiction = 0;
        if (match(call_num, /^(-)$/)) {
            call_num = $8;
            # The 'n' or 'y' for non fiction or fiction is in column $9 and converted to an integer of 0 or 1.
            if ($9 == "y") {
                fiction = 1;
            }
        } else {
            if ($8 == "y") {
                fiction = 1;
            }
        }
        if (match(call_num, /^(-)$/)) {
            call_num = "NULL";
        } else {
            call_num = "'"call_num"'";
        }
        publication_year = $4;
        # Some items don't have publication years so output a null value.
        if (publication_year <= 0) {
            publication_year = "NULL";
        }
        
        
        # The output string _may_ have some NULL values which are not quoted so build the string piece by piece
        my_query = "("$1", '"title"', '"author"', "publication_year", "title_holds", '"$6"', "call_num", "fiction", '"date"')";
        # Stop extra new line using printf.
        printf "%s",my_query;
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