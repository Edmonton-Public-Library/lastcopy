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
## Count circulating copies query
```sql
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

