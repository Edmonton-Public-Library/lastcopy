#!usr/bin/env awk

BEGIN {
    FS="|";
    insertStatement = "INSERT OR IGNORE INTO titles (CKey, TCN, Author, Title, PubYear, Series, THolds) VALUES ";
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
    ## Duplicate chars to compensate for syntax hi-lite not resetting on end of this regex.
    ## Remove quotes from titles. Add to regex if you find more characters that break the INSERT SQL.
    gsub(/[`,]/, "", $0);
    ## Get rid of the trailing space in TCNs.
    gsub(/[ ]+$/, "", $2);
    tcn = $2;
    ## Determine series information.
    series = "na";
    if ($6 ~ /[0-9A-Za-z]/) {
        series = $6;
    }
    # More commonly series info is in the 490. If it is overwrite 'series' var and if not, it was set to either 380 or 'na' above.
    if ($7 ~ /[0-9A-Za-z]/) {
        series = $7;
    }
    ## Typically series is just a phrase like 'Potter House series', but sometimes it's more like:
    ## 'Tom Clancy's Op-Center series ; v. 18'. In these cases let's strip off everything after the ';'
    gsub(/;.+$/, "", series);
    # Trim off the last space before the end if necessary.
    gsub(/[ ]+$/, "", series);
    printf "(%d, '%s', '%s', '%s', %d, '%s', %d)",$1,tcn,$3,$4,$5,series,$8;
    if (count == -1){
        printf ",\n";
    }
    count++;
} 

END {
    print ";";
    print "END TRANSACTION;";
}