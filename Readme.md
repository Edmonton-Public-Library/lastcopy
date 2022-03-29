# lastcopy Readme
## 2021-11-22
Turns out last copy is too late. By the time we are down to the last copy, staff may have deleted the holds, and the discard process will happily purge the record, and the title in the process.

A better solution is to be proactive. Collect data on titles that are vulnerable because they are in the last stages of their life cycle. 

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
Tables_in_appsng(_dev)
* [last_copy_item_complete_statuses](#table-lastcopyitemcompletestatuses)
* [last_copy_item_statuses](#table-lastcopyitemstatuses)
* [last_copy_items](#table-lastcopyitems)
* [last_copy_series](#table-lastcopyseries)
* [last_copy_series_titles](#table-lastcopyseriestitles)
* [last_copy_titles](#table-lastcopytitles)

**Note to developer**; given the constraints of foreign keys in the schema, load item information before title information.


## Table: last_copy_titles
This table contains information about titles that are at risk of having only last copies of items.

| **Field** | **Type** | **Null** | **Key** | **Default** | **Extra** |
|:---|---:|---:|---:|---:|---:|
| id | bigint | unsigned | NO | PRI | NULL | 
| title | varchar(255) | NO | NULL | 
| author | varchar(255) | YES | NULL | 
| publication_year | int | NO | NULL | 
| title_holds | int | NO | NULL |

## Table: last_copy_items
Contains information about specific items. These items have been identified as representative of a title at risk.
| **Field** | **Type** | **Null** | **Key** | **Default** | **Extra** |
|:---|---:|---:|---:|---:|---:|
| id | bigint | unsigned | NO | PRI | NULL | 
| last_copy_title_id | bigint | unsigned | NO | MUL | NULL | 
| call_number | int | NO | NULL | 
| copy_number | int | NO | NULL | 
| checkouts | int | NO | NULL | 
| current_location | varchar(255) | NO | NULL | 
| item_type | varchar(25) | NO | NULL | 
| copy_holds | int | NO | NULL | 
| last_active | date | NO | NULL | 
| last_charged | date | NO | NULL | 
| last_copy_item_status_id | bigint | unsigned | YES | MUL | NULL | 
| last_copy_item_complete_status_id | bigint | unsigned | YES | MUL | NULL | 
| notes | varchar(255) | NO | NULL | 
| is_reviewed | timestamp | NO | NULL | 
| snooze_until | timestamp | YES | NULL | 
| updated_by_user_id | char(36) | YES | MUL | NULL |

## Table: last_copy_series
This table groups lets staff create a series object that other titles can be attached to, and be managed as one title.

| **Field** | **Type** | **Null** | **Key** | **Default** | **Extra** |
|:---|---:|---:|---:|---:|---:|
| id | bigint | unsigned | NO | PRI | NULL | auto_increment | 
| name | varchar(255) | NO | NULL | 
| description | varchar(255) | NO | NULL | 
| updated_by_user_id | char(36) | YES | MUL | NULL | 
| deleted_at | timestamp | YES | NULL |


## Table: last_copy_series_titles
This table groups disperate catalog records together. For example 'Buffy the Vampire Slayer' but has many seasons catalogued as a separate records. Each of those records can be entered here, and associated as a series in [last_copy_series](#table-lastcopyseries).

| **Field** | **Type** | **Null** | **Key** | **Default** | **Extra** |
|:---|---:|---:|---:|---:|---:|
| id | bigint | unsigned | NO | PRI | NULL | auto_increment | 
| last_copy_series_id | bigint | unsigned | NO | MUL | NULL | 
| last_copy_title_id | bigint | unsigned | NO | MUL | NULL | 
| updated_by_user_id | char(36) | YES | MUL | NULL | 
| deleted_at | timestamp | YES | NULL |


## Table: last_copy_complete_statuses
To be used by appsng as list of status staff can apply to a title within the database. Some examples may be, 'Purchased', 'Under review', 'Not ordering' and the like.

## Table: last_copy_item_statuses
This a table of items (should be titles?) and asscociated statuses.



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

