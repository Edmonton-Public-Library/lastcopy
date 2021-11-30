# lastcopy Readme
## 2021-11-22
Turns out last copy is too late. By the time we are down to the last copy, staff may have deleted the holds, and the discard process will happily purge the record, and the title in the process.

A better solution is to be proactive. Collect data on titles that are volnerable because they are in the last stages of their life cycle. 

The acquisitions librarians have identified several metrics, and pinch points they encounter while determining if a title needs intervention.

## Determining risk
A title is at risk if it can be catagorized by any of the following.
- [There are zero or one circulatable copies on a title](#Count circulating copies query).
-- Locations that are not circulatable are as follows. UNKNOWN, MISSING, LOST, DISCARD, LOST-PAID, LONGOVRDUE, CANC_ORDER, INCOMPLETE, DAMAGE, BARCGRAVE, NON-ORDER, LOST-ASSUM, LOST-CLAIM, STOLEN, NOF.
- Titles, all of whose items have circulations higher than a given threshold. The threshold may vary by item type, but all users agree on what the threshold is for each item type.

## Pinch points in this process
Several problems occur while trying to determine if a title is a risk.
- Series titles are not cataloged consistently. Some use 490, and less frequently 830 tags to indicate volumes.
- Similar titles should be identified to be merged.

# Schema
```sql
CREATE TABLE Items (ckey INT, callnum INT, cpnum INT, total INT, cloc TEXT, itype TEXT, cholds INT, tholds INT);
CREATE INDEX idx_ckey ON Items (ckey);
CREATE INDEX idx_ckey_callnum ON Items (ckey, callnum);
CREATE INDEX idx_itype ON Items (itype);
CREATE INDEX idx_cloc ON Items (cloc);
```
Modified
```sql
CREATE TABLE IF NOT EXISTS catalog_titles (
    id INT PRIMARY KEY NOT NULL, -- This is the cat key
    title VARCHAR 255 NOT NULL,
    author VARCHAR 255,
    publication_year INT
);

CREATE TABLE IF NOT EXISTS catalog_items (
    catalog_title_id INT,
    call_number INT,
    copy_number INT,
    checkouts INT,
    current_location VARCHAR (25),
    item_type VARCHAR (25),
    copy_holds INT,
    title_holds INT,
    last_active DATE,
    last_charged DATE,
    bar_code INT PRIMARY KEY,
    FOREIGN KEY (catalog_title_id)
        REFERENCES catalog_titles (id)
        ON UPDATE RESTRICT
        ON DELETE RESTRICT
);
```


## Grubby List
List the titles and total checkouts where all the items have 80 or more charges.
```sql
select ckey,sum(ckos) from Items group by ckey having min(ckos) >= 80;
```

## Count circulating copies query
List the ckeys where the total circulatable items are 0 or 1.
```sql
select ckey, (
    select count(cloc) 
    from Items 
    where ckey=I.ckey and cloc not in (
        'DISCARD','STOLEN','DAMAGE','MISSING','UNKNOWN',
        'BINDERY','LOST','LOST-ASSUM','LOST-CLAIM','NOF',
        'NON-ORDER','CANC_ORDER','INCOMPLETE'
    )
) IC from Items as I 
where IC <= 1 
group by ckey 
ORDER BY IC ASC;
```

# Instructions for Running:
The script can be run by hand if desired, but it is suggested that it be run daily at a quiet since collecting the data is temporally intensive.

# Product Description:
Bash shell script written by Andrew Nisbet for Edmonton Public Library, distributable by the enclosed license.

# Repository Information:
This product is under version control using Git.

# Dependencies:
* [pipe.pl](https://github.com/anisbet/pipe)

# Known Issues:
None

