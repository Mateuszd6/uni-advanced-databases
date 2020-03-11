-- This table is required for everything below to work.
DROP TAbLE IF EXISTS ccid;
CREATE TAbLE ccid (
    per_id INT NOT NULL PRIMARY KEY,
    cc INT NOT NULL
);

CREATE FUNCTION displ_graph_result()
RETURNS TAbLE(a int, b bigint)
AS $$
SELECT cc,
       COUNT(cc) cnt
FROM ccid
GROUP BY cc
ORDER BY cnt DESC
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION gsrch()
    RETURNS INTEGER AS $$
DECLARE
    counter INTEGER := 0;
    num_updated INTEGER := 0;
BEGIN
    -- Init ccid table.
    DELETE FROM ccid;
    INSERT INTO ccid (per_id, cc)
    SELECT id, id
    FROM person;

    LOOP
        WITH newvals AS (
            SELECT MIN(LEAST(c_1.cc, c_2.cc)) AS must_be,
                   GREATEST(c_1.cc, c_2.cc) AS is_now
            FROM graph g
            JOIN ccid c_1 ON c_1.per_id = g.per1_id
            JOIN ccid c_2 ON c_2.per_id = g.per2_id
            GROUP BY GREATEST(c_1.cc, c_2.cc)
            ORDER BY is_now
        )
        , inserted AS (
            UPDATE ccid
            SET cc = n.must_be
            FROM newvals n
            WHERE cc = n.is_now AND n.is_now > n.must_be
            RETURNING 1 AS i
        )
        SELECT COUNT(i)
        INTO num_updated
        FROM inserted;

        RAISE NOTICE 'Updated % records in iteration %', num_updated, counter;
        SELECT (counter + 1) INTO counter;
        EXIT WHEN (num_updated = 0);
    END LOOP;

    RETURN num_updated;
END $$
LANGUAGE plpgsql;

-- All edges
DROP MATERIALIZED VIEW IF EXISTS graph;
CREATE MATERIALIZED VIEW graph
AS
SELECT per1_id, per2_id
FROM v_graph;
CREATE INDEX graph_idx ON graph USING btree (per1_id);
CLUSTER graph USING graph_idx;

-- About 70th percentile.
DROP MATERIALIZED VIEW IF EXISTS graph;
CREATE MATERIALIZED VIEW graph
AS
SELECT per1_id, per2_id
FROM v_graph
WHERE cnt > 1;
CREATE INDEX graph_idx ON graph USING btree (per1_id);
CLUSTER graph USING graph_idx;

-- About 86th percentile.
DROP MATERIALIZED VIEW IF EXISTS graph;
CREATE MATERIALIZED VIEW graph
AS
SELECT per1_id, per2_id
FROM v_graph
WHERE cnt > 2;
CREATE INDEX graph_idx ON graph USING btree (per1_id);
CLUSTER graph USING graph_idx;

-- About 99th percentile.
DROP MATERIALIZED VIEW IF EXISTS graph;
CREATE MATERIALIZED VIEW graph
AS
SELECT per1_id, per2_id
FROM v_graph
WHERE cnt > 12;
CREATE INDEX graph_idx ON graph USING btree (per1_id);
CLUSTER graph USING graph_idx;
