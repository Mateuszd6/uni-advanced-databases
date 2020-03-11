-- First save the query as a function for convenience.
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
       (SELECT STRING_AGG(_per.name, ', ')
        FROM person_publication _pp
        JOIN person _per
          ON _per.id = _pp.person_id
        WHERE _pp.publ_id = publ.id)
FROM pid
JOIN person_publication pp
  ON pp.person_id = pid._id
JOIN publication publ
  ON publ.id = pp.publ_id
JOIN person per
  ON per.id = pp.person_id
ORDER BY publ.year desc
$$ LANGUAGE SQL;

-- This returns the time of the execution of the query passed as parameter.
CREATE OR REPLACE FUNCTION measure_time(query TEXT)
RETURNS DOUBLE PRECISION
AS $$
DECLARE
   j json;
BEGIN
   EXECUTE 'EXPLAIN (ANALYZE, FORMAT JSON) ' || query INTO j;
   RETURN (j->0->>'Execution Time')::double precision;
END;
$$ LANGUAGE plpgsql;

-- Copied from postgresql wiki
CREATE OR REPLACE FUNCTION random_between(low INT, high INT)
RETURNS INT
AS $$
BEGIN
   RETURN floor(random()* (high-low + 1) + low);
END;
$$ LANGUAGE 'plpgsql';

-- This will give us list of authors that have many (many means more than 52)
-- publications, sort them and for each 400 will pick 1 each with the same
-- probability.

CREATE TAbLE authors_probe (
    id BIGINT PRIMARY KEY NOT NULL,
    name VARCHAR,
    numpubls INT,
    sid INT,
    num_group INT
);

CREATE TAbLE benchmark (
    id BIGSERIAL PRIMARY KEY NOT NULL,
    author_id BIGINT REFERENCES authors_probe(id),
    time DOUBLE PRECISION,
    first_called INT
);

-- This will insert some authors with many publications into the authors_probe
-- table.
\set group_size 400
\set num_random_users 100
\set min_num_of_publs 52
WITH authors_sorted AS (
    SELECT p.id,
           p.name,
           COUNT(*) AS numpubls,
           row_number() OVER (ORDER BY COUNT(*) DESC) sid
    FROM person p
    JOIN person_publication pp
      ON pp.person_id = p.id
    GROUP BY p.id, p.name
    ORDER BY sid
)
, random_authors_ids AS (
    SELECT ser - 1 AS div,
           random_between((ser - 1) * :group_size,
                          LEAST(ser * :group_size,
                                CAST((SELECT COUNT(*) FROM authors_sorted) AS INT)) - 1)
           % :group_size AS rem
    FROM generate_series(1, CAST(Ceil(CAST((SELECT COUNT(*) FROM authors_sorted) AS DECIMAL) / :group_size) AS INT)) ser
)
INSERT INTO authors_probe (
    id,
    name,
    numpubls,
    sid,
    num_group
)
(SELECT a.id,
        a.name,
        a.numpubls,
        a.sid,
        1
 FROM authors_sorted a
 JOIN random_authors_ids rai
   ON rai.div = floor(a.sid / :group_size) AND rai.rem = a.sid % :group_size
 WHERE a.numpubls >= :min_num_of_publs)
UNION
(SELECT a.id,
        a.name,
        a.numpubls,
        a.sid,
        2
 FROM authors_sorted a
 WHERE a.id NOT IN (SELECT id FROM authors_probe)
 ORDER BY RANDOM()
 LIMIT :num_random_users);

-- Now make some benchmarks. This procedure is indented to be repeted few times.
INSERT INTO benchmark (
    author_id,
    time,
    first_called
)
SELECT ap.id,
       measure_time('SELECT * FROM get_publs_for_author(''' || ap.name || ''');'),
       1
FROM authors_probe ap
ORDER BY ap.numpubls DESC;

-- This will display the benchmarks results.
SELECT ap.name,
       ap.sid as order,
       ap.numpubls,
       bench._min,
       bench._avg,
       bench._max
FROM (SELECT b.author_id,
             MIN(b.time) as _min,
             AVG(b.time) as _avg,
             MAX(b.time) as _max
      FROM benchmark b
      GROUP BY b.author_id) bench
JOIN authors_probe ap
  ON ap.id = bench.author_id
ORDER BY ap.numpubls DESC;
