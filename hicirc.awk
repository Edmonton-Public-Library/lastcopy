#!usr/bin/env awk
BEGIN{
    FS="|";
    print"INSERT INTO Charges (ckey,total) VALUES ";
}

# For any non-empty entry print the values to insert to the Charges table.
/^[0-9]/ {
    print "("$1","$2"),";
}

END{
    print "(0,0);";
}