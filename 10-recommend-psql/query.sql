-- Results in the spreadsheet file.

-- Missing indecies.
CREATE INDEX graph_per1 ON public.graph USING btree (per1);
CREATE INDEX graph_per2 ON public.graph USING btree (per2);
CREATE UNIQUE INDEX graph_pkey ON public.graph USING btree (per1, per2);

-- Weight for each journal, and corresponding aux functions.
-- DEPTH(p) = (Shortest path to vertex p)
-- NPUBLS(p) = Number of common publications with person p
-- NUM_ARTICLES(p, j) = Numer of times person p wrote into journal j.
-- PERSON_WEIGHT(p) = (NPUBLS(p) + (1 / DEPTH(p)^4))
-- JOURNAL_WEIGHT(j) = SUM OVER ALL NEIGHTBOUR p: PERSON_WEIGHT(p) * (1 + (NUM_ARTICLES(p, j) / 10))
--

-- root_name: the name of the person to find recommendations.
-- iterations: the biggest acceptable numer of edges away from the root.
-- edge_weight_limit: select only edges with weight gr/eq toedge_weight_limit.
-- print_debug: print a json that can be handy when trying to determine how weight was calculated.
DROP FUNCTION IF EXISTS get_recommendations(VARCHAR, INT, INT, INT);
CREATE FUNCTION get_recommendations(root_name VARCHAR, iterations INT, edge_weight_limit INT, print_debug INT)
RETURNS TABLE (
      journal TEXT,
      weight DOUBLE PRECISION,
      dbg_source JSON
)
AS $$
DECLARE
    root BIGINT := 0;
BEGIN
    root := (SELECT id FROM person WHERE name = root_name);

    DROP TAbLE IF EXISTS tmp_neighbours;
    CREATE TEMP TAbLE tmp_neighbours(
        per BIGINT NOT NULL,
        depth INT NOT NULL,
        PRIMARY KEY(per)
    );

    INSERT INTO tmp_neighbours (per, depth)
    VALUES (root, 0); -- There is no node with id 0.

    FOR i IN 1..iterations LOOP
        WITH q AS (
            SELECT g1.per2 AS n1,
                   g2.per1 AS n2
            FROM tmp_neighbours n
            JOIN graph g1
              ON g1.per1 = n.per
            JOIN graph g2
              ON g2.per2 = n.per
            WHERE g1.w1 >= edge_weight_limit
              AND g2.w1 >= edge_weight_limit
        )
        , new_nodes AS (
            SELECT n1
            FROM (SELECT n1 FROM q UNION SELECT n2 FROM q) s
            WHERE n1 NOT IN -- Dicard nodes that were already selected.
                  (SELECT per FROM tmp_neighbours)
        )
        INSERT INTO tmp_neighbours
        SELECT n1, i
        FROM new_nodes;
    END LOOP;

    RETURN QUERY
    WITH p AS (
        SELECT n.per AS perid,
               MIN(per.name) AS pername,
               p.journal,
               (COALESCE(MIN(w1), 1)::DOUBLE PRECISION) / (n.depth * n.depth * n.depth * n.depth) AS person_weight,
               COUNT(p.journal) AS num_articles
        FROM tmp_neighbours n
        LEFT JOIN graph g
          ON ((n.per = g.per1 AND g.per2 = 273742) OR (n.per = g.per2 AND g.per1 = 273742))
        JOIN person per
          ON per.id = n.per
        JOIN person_publication pp
          ON pp.person_id = n.per
        JOIN publication p
          ON p.id = pp.publ_id
        WHERE depth > 0 -- Don't select self;
          AND p.publication_type = 'article'
          AND p.journal IS NOT NULL AND p.journal <> '' -- Discard null and empty values
        GROUP BY (per, p.journal)
        ORDER BY person_weight DESC
    )
    , exclude_publs AS (
        SELECT DISTINCT p.journal AS journal_to_exclude
        FROM publication p
        JOIN person_publication pp
          ON pp.publ_id = p.id
        WHERE pp.person_id = 273742
          AND p.publication_type = 'article'
    )
    , res AS (
        SELECT p.journal::TEXT AS journal_name,
               SUM(person_weight * ((1::DOUBLE PRECISION) + (num_articles / 10::DOUBLE PRECISION))) AS weight,
               CASE
                   WHEN print_debug <> 0 THEN
                        JSON_AGG(json_build_object('p', pername, 'pw', person_weight, 'num', num_articles)
                                 ORDER BY person_weight DESC)
                   ELSE NULL
               END AS dbg_source
        FROM p
        WHERE p.journal NOT IN (SELECT journal_to_exclude FROM exclude_publs)
        GROUP BY p.journal
    )
    SELECT res.journal_name, res.weight, res.dbg_source
    FROM res
    ORDER BY res.weight DESC
    LIMIT 100;
END;
$$ LANGUAGE plpgsql;

--
-- We accpet vertices three edges away, but the graph percentile is so
-- height that the connected component is small anyway so the results
-- are not that noisy.
--
SELECT * FROM get_recommendations('Krzysztof Stencel', 3, 12, 1) LIMIT 5;

-- Benchmarking:
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

INSERT INTO benchmark (
    author_id,
    time,
    first_called
)
SELECT ap.id,
       measure_time('SELECT * FROM get_recommendations(''' || ap.name || ''', 2, 6, 0) LIMIT 5;'),
       1
FROM authors_probe ap
ORDER BY ap.numpubls DESC;

-- This will display the benchmarks results.
DROP MATERIALIZED VIEW IF EXISTS tmp_v;
CREATE MATERIALIZED VIEW tmp_v AS
SELECT ap.name,
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
ORDER BY numpubls DESC;

\copy (SELECT * FROM tmp_v) TO 'bench1.csv' DELIMITER ',' CSV;


--
-- Same results are in the spreadsheet file and are probably more readable.
--

-- The parameters selcted for the queries are found by experimenting
-- the values. Allow for the neighbours up tp three edges away but
-- select as big graph percentile as it is possible (The
-- largest that provides any result at all).

-- SELECT * FROM get_recommendations('Krzysztof Stencel', 3, 12, 0) LIMIT 5;
--
--            journal           |       weight
-- -----------------------+--------------------
--  Annales UMCS, Informatica   |  56.10000000000001
--  Multiagent and Grid Systems | 42.900000000000006
--  Inf. Syst.                  |               37.8
--  Comput. J.                  |               32.4
--  ACM Trans. Database Syst.   | 29.700000000000003


-- SELECT * FROM get_recommendations('Krzysztof Diks', 3, 8, 0) LIMIT 5;
--
--         journal        |       weight
-- -----------------------+--------------------
--  Theor. Comput. Sci.   | 26.497067901234583
--  Inf. Process. Lett.   |  18.66674382716049
--  Algorithmica          | 12.739274691358016
--  Inf. Comput.          | 10.338271604938276
--  Distributed Computing | 10.333179012345683


-- SELECT * FROM get_recommendations('Thomas H. Cormen', 3, 3, 0) LIMIT 5;
--
--            journal            |      weight
-- ------------------------------+-------------------
--  SIAM J. Comput.              | 6.630709876543212
--  J. ACM                       | 5.216666666666667
--  Algorithmica                 | 5.085493827160496
--  J. Parallel Distrib. Comput. | 4.694907407407415
--  IEEE Trans. Computers        | 4.604243827160496


-- SELECT * FROM get_recommendations('Donald E. Knuth', 3, 3, 0) LIMIT 5;
--
--               journal              |       weight
-- -----------------------------------+--------------------
--  The American Mathematical Monthly | 22.993750000000006
--  J. Comb. Theory, Ser. A           | 10.962499999999997
--  Discrete Mathematics              |  9.899999999999995
--  Electr. J. Comb.                  |  6.775000000000001
--  Adv. Appl. Math.                  |  5.856250000000001
