-- Median Aggregate copied from:
-- https://wiki.postgresql.org/wiki/Aggregate_Median
CREATE OR REPLACE FUNCTION _final_median(NUMERIC[])
   RETURNS NUMERIC AS
$$
   SELECT AVG(val)
   FROM (
     SELECT val
     FROM unnest($1) val
     ORDER BY 1
     LIMIT  2 - MOD(array_upper($1, 1), 2)
     OFFSET CEIL(array_upper($1, 1) / 2.0) - 1
   ) sub;
$$
LANGUAGE 'sql' IMMUTaBLE;
CREATE AGGREGATE median(NUMERIC) (
  SFUNC=array_append,
  STYPE=NUMERIC[],
  FINALFUNC=_final_median,
  INITCOND='{}'
);

CREATE OR REPLACE FUNCTION displ_indexes()
RETURNS table(
    tablename NAME,
    indexname NAME,
    indexdef TEXT)
AS $$
SELECT
    tablename,
    indexname,
    indexdef
FROM
    pg_indexes
WHERE
    schemaname = 'public'
ORDER BY
    tablename,
    indexname;
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION displ_indexes_scm(VARCHAR) -- $1 is a schema name
RETURNS table(
    tablename NAME,
    indexname NAME,
    indexdef TEXT)
AS $$
SELECT
    tablename,
    indexname,
    indexdef
FROM
    pg_indexes
WHERE
    schemaname = $1
ORDER BY
    tablename,
    indexname;
$$ LANGUAGE SQL;

-- Now make some benchmarks. This procedure is indented to be repeted few times.
CREATE OR REPLACE FUNCTION run_benchmark(INT) -- arg is a number of benchmark
RETURNS VOID
AS $$
INSERT INTO benchmark (
    author_id,
    time,
    first_called
)
SELECT ap.id,
       measure_time('SELECT * FROM get_publs_for_author(''' || ap.name || ''');'),
       $1
FROM authors_probe ap
ORDER BY RANDOM() DESC;
$$ LANGUAGE SQL;

-- First_called is meaningfull - its a 2 digit number where the first represents
-- the benchmarks optimization set and the second is just a test number in the set.
CREATE OR REPLACE FUNCTION displ_benchmark_results(INTEGER)
RETURNS table(
    author_name VARCHAR,
    numpubls INTEGER,
    worse DOUBLE PRECISION,
    best DOUBLE PRECISION,
    average NUMERIC,
    median NUMERIC)
AS $$
WITH bench_values AS (
    SELECT b.author_id AS author_id,
           MAX(b.time) AS maxtime,
           MIN(b.time) AS mintime,
           ROUND(AVG(b.time)::NUMERIC, 3) AS avgtime,
           ROUND(median(CAST (b.time AS NUMERIC)), 3) AS medtime
    FROM benchmark b
    WHERE b.first_called >= $1
      AND b .first_called < $1 + 10
    GROUP BY b.author_id
)
SELECT ap.name,
       ap.numpubls,
       maxtime,
       mintime,
       avgtime,
       medtime
FROM bench_values bv
JOIN authors_probe ap
  ON ap.id = bv.author_id
ORDER BY numpubls DESC;
$$ LANGUAGE SQL;

--
-- Optimization:
--

---
--- First optimization: add idx on person_publication
---
CREATE UNIQUE INDEX person_publication_idx ON person_publication USING btree (person_id, publ_id);

--
-- Second optimization: Change b+trees to hashes where applicable
--
CREATE INDEX namealias_name_hash_idx ON namealias USING hash (name);
CREATE INDEX person_name_hash_idx ON person USING hash (name);

-- Missed when creating DB
ALTER TAbLE namealias ADD CONSTRAINT namealias_name_key UNIQUE (name);

--
-- Thrid optimization: Cluster person_publication table.
--
CLUSTER TABLE person_publication USING person_publication_pkey;

--
-- Fourth optimization: Materialized view to avoid aggregating author names.
--
CREATE MATERIALIZED VIEW publ_author_names
AS
SELECT publ.id,
       (SELECT STRING_AGG(_per.name, ', ')
        FROM person_publication _pp
        JOIN person _per
          ON _per.id = _pp.person_id
        WHERE _pp.publ_id = publ.id) AS names
FROM publication publ;

-- Now use the view from above:
CREATE OR REPLACE FUNCTION get_publs_for_author(VARCHAR)
RETURNS table(
       id BIGINT,
       year SMALLINT,
       title VARCHAR,
       publication_type publ_t,
       autor_type author_t,
       authors VARCHAR)
AS $$
WITH pid AS (
  (SELECT per.id as _id
   FROM namealias n
   JOIN person per
     ON per.id = n.person_id
   WHERE n.name = $1)
  UNION
    (SELECT id as _id
     FROM person per
     WHERE per.name = $1)
  LIMIT 1
)
SELECT publ.id,
       publ.year,
       publ.title,
       publ.publication_type,
       pp.autor_type,
       pan.names
FROM pid
JOIN person_publication pp
  ON pp.person_id = pid._id
JOIN publication publ
  ON publ.id = pp.publ_id
JOIN person per
  ON per.id = pp.person_id
JOIN publ_author_names pan
  ON pan.id = publ.id
ORDER BY publ.year desc
$$ LANGUAGE SQL;
