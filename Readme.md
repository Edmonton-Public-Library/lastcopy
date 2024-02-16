# lastcopy
Finds last copies of items in the ILS and reports important information such as number of holds, circ counts, current location, and user catagory 2.
The data is converted to SQL and loaded into Apps-NG.

## TODO
* Titles with multiple call numbers should be included if the title as a whole, has less than 2 active copies.

## 2024 -02-15
* Refactored to modern bash syntax.
* Added tests to scripts.
* Added item cat2 and home location to lastcopy_compiler.sh.
* Removed non-circ locations in lastcopy_compiler.sh.
  
## 2021-11-22
Turns out last copy is too late. By the time we are down to the last copy, staff may have deleted the holds, and the discard process will happily purge the record, and the title in the process.

A better solution is to be proactive. Collect data on titles that are vulnerable because they are in the last stages of their life cycle. 

The acquisitions librarians have identified several metrics, and pinch points they encounter while determining if a title needs intervention.

## Determining risk
A title is at risk if it can be catagorized by any of the following.
- [There are zero or one circulatable copies on a title](#count-circulating-copies-query).
  - Locations that are not circulatable are as follows. UNKNOWN, MISSING, LOST, DISCARD, LOST-PAID, LONGOVRDUE, CANC_ORDER, INCOMPLETE, DAMAGE, BARCGRAVE, NON-ORDER, LOST-ASSUM, LOST-CLAIM, STOLEN, NOF.
- Titles, all of whose items have circulations higher than a given threshold. The threshold may vary by item type, but all users agree on what the threshold is for each item type.

## Pinch points in this process
Several problems occur while trying to determine if a title is a risk.
- Series titles are not cataloged consistently. Some use 490, and less frequently 830 tags to indicate volumes.
- Similar titles should be identified to be merged.

# Scripts
* [lastcopy.sh](#last_copy) Reports all titles, the number of items, holds, and circulatable copies on the title.
* [series.sh](#series) report titles and the series to which they belong.
* [grubby.sh](#grubby) report items with more than 'n' circs, or alternatively titles all of who's items have more than 'n' circs.

## Last Copy
A simple shell script found in bincustom that computes which titles have one or fewer circulating copies. The number is configurable.

The output of the script is a pipe-delimited file containing the cat key, number of holds, and number of visible copies.
```bash
ckey   |items|holds|circulatable copies|
1000009|1|0|1|
1000012|1|0|0|
```
Once collected additional information can be gotten via the Symphony API.

## Series
Collects all the titles related as a series.
```bash
ckey   |series              |
2474268|Yao guai xin wen she|
2474269|Yao guai xin wen she|
```

## Grubby
Grubby list is a common term in libraries which refers to items that have more than a given number of circs. The twist here is we want to know all the titles whose entire set of circulatable copies have more than a given number of charges.
```bash
ckey   |Minimum circs on all items|              |
1000009|88|
1000028|33|
```

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
| **title_control_number** | varchar(25) | YES | NULL | | Proposed addition |
| title | varchar(255) | NO | NULL | 
| author | varchar(255) | YES | NULL | 
| publication_year | int | NO | NULL | 
| title_holds | int | NO | NULL |
| is_fiction | varchar | NO | NULL |

## Table: last_copy_items
Contains information about specific items. These items have been identified as representative of a title at risk.
| **Field** | **Type** | **Null** | **Key** | **Default** | **Extra** |
|:---|---:|---:|---:|---:|---:|
| id | bigint | unsigned | NO | PRI | NULL | 
| last_copy_title_id | bigint | unsigned | NO | MUL | NULL |  
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

# Issues
* Multiple items show as last copy, that is, two discarded items on a title show as a last copy rather than strictly one last copy staff want just last copies.
* Some titles with multiple available copies occasionally show up in database (31221317302276 is an example)