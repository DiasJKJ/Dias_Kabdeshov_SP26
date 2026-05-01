-- How space changed:
-- Initial size: 575 MB and After DELETE: 575 MB 
-- After VACUUM FULL: 383 MB
-- After TRUNCATE: 8 KB
-- So after delete no barely no meaningful change happened
-- A little bit of spaced reducation by VACUUM FULL
-- And TRUNCATE Of course basically emptied the whole thing
-- It is like this because after DELETE does its stuff, its still stored physically
-- Because of MVCC, but then VACUUM removes it because it basically rewrites the whole table
-- and removes unused stuff
-- TRUNCATE operates so fast because it basically resets everything
-- without going row by row

-- DELETE vs TRUNCATE

-- Execution time:
-- DELETE: 16 seconds, so it was slow, because its row-by-row
-- TRUNCATE: 155 ms, it is very fast because of  metadata operation

-- Transaction behavior:
-- DELETE is fully transactional because its DML
-- TRUNCATE is also transactional but it behaves like DDL




-- 1

DROP TABLE IF EXISTS table_to_delete;

CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x;	
-- took 22 seconds

-- 2

SELECT *, 
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table
FROM (
    SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
    FROM (
        SELECT c.oid,
               nspname AS table_schema,
               relname AS table_name,
               c.reltuples AS row_estimate,
               pg_total_relation_size(c.oid) AS total_bytes,
               pg_indexes_size(c.oid) AS index_bytes,
               pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

"oid"	"table_schema"	"table_name"	"row_estimate"	"total_bytes"	"index_bytes"	"toast_bytes"	"table_bytes"	"total"	"index"	"toast"	"table"
"16891"	"public"	"table_to_delete"	-1	            602415104	0	8192	602406912	"575 MB"	"0 bytes"	"8192 bytes"	"575 MB"

-- 3. DELETE

DELETE FROM table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0;
-- took 16 seconds

-- 3b. 

SELECT *, 
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table
FROM (
    SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
    FROM (
        SELECT c.oid,
               nspname AS table_schema,
               relname AS table_name,
               c.reltuples AS row_estimate,
               pg_total_relation_size(c.oid) AS total_bytes,
               pg_indexes_size(c.oid) AS index_bytes,
               pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

"oid"	"table_schema"	"table_name"	"row_estimate"	"total_bytes"	"index_bytes"	"toast_bytes"	"table_bytes"	"total"	"index"	"toast"	"table"
"16891"	"public"	"table_to_delete"	1.0000367e+07	602611712	0	8192	602603520	"575 MB"	"0 bytes"	"8192 bytes"	"575 MB"

-- 3c. 

VACUUM FULL VERBOSE table_to_delete;
-- Took 7 seconds

-- 3d. 

SELECT *, 
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table
FROM (
    SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
    FROM (
        SELECT c.oid,
               nspname AS table_schema,
               relname AS table_name,
               c.reltuples AS row_estimate,
               pg_total_relation_size(c.oid) AS total_bytes,
               pg_indexes_size(c.oid) AS index_bytes,
               pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

"oid"	"table_schema"	"table_name"	"row_estimate"	"total_bytes"	"index_bytes"	"toast_bytes"	"table_bytes"	"total"	"index"	"toast"	"table"
"16891"	"public"	"table_to_delete"	6.666667e+06	401580032	0	8192	401571840	"383 MB"	"0 bytes"	"8192 bytes"	"383 MB"

-- 3e. 

DROP TABLE table_to_delete;

CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x;
-- Took 21 seconds

-- 4. TRUNCATE

TRUNCATE table_to_delete;
-- Took 155 msec

-- 4c

SELECT *, 
       pg_size_pretty(total_bytes) AS total,
       pg_size_pretty(index_bytes) AS index,
       pg_size_pretty(toast_bytes) AS toast,
       pg_size_pretty(table_bytes) AS table
FROM (
    SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
    FROM (
        SELECT c.oid,
               nspname AS table_schema,
               relname AS table_name,
               c.reltuples AS row_estimate,
               pg_total_relation_size(c.oid) AS total_bytes,
               pg_indexes_size(c.oid) AS index_bytes,
               pg_total_relation_size(reltoastrelid) AS toast_bytes
        FROM pg_class c
        LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE relkind = 'r'
    ) a
) a
WHERE table_name LIKE '%table_to_delete%';

"16901"	"public"	"table_to_delete"	-1	8192	0	8192	0	"8192 bytes"	"0 bytes"	"8192 bytes"	"0 bytes"