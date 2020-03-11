-- As we reference number of authors of publication many times we store this
-- data in a materialized view.
CREATE MATERIALIZED VIEW v_publ_num_authors
AS
SELECT pp.publ_id, COUNT(pp.person_id)
FROM person_publication pp
GROUP BY pp.publ_id;

CREATE UNIQUE INDEX v_pulb_num_authors_idx ON v_publ_num_authors USING btree (publ_id);

CREATE MATERIALIZED VIEW v_graph
AS
SELECT pp1.person_id AS per1_id,
       pp2.person_id AS per2_id,
       COUNT(pp1.publ_id) AS cnt,
       SUM((1::double precision) / (vpna.count - 1)) AS  fancy
FROM person_publication pp1
JOIN person_publication pp2
  ON pp1.publ_id = pp2.publ_id AND pp1.person_id < pp2.person_id
JOIN v_publ_num_authors vpna
  ON vpna.publ_id = pp1.publ_id
GROUP BY pp1.person_id, pp2.person_id
ORDER BY pp1.person_id, pp2.person_id;

CREATE UNIQUE INDEX v_graph_pkey ON v_graph USING btree (per1_id, per2_id);


--
-- Make a graph based on the publication type (books and theeses worth much more
-- than articles/proceedings/etc)
--
CREATE MATERIALIZED VIEW v_graph_by_type
AS
SELECT pp1.person_id AS per1_id,
       pp2.person_id AS per2_id,
       SUM(CASE WHEN (p.publication_type <> 'article'
                   AND p.publication_type <> 'incollection'
                   AND p.publication_type <> 'inproceedings'
                   AND p.publication_type <> 'proceedings')
             THEN 20
             ELSE 1
        END) AS weight
FROM person_publication pp1
JOIN person_publication pp2
  ON pp1.publ_id = pp2.publ_id AND pp1.person_id < pp2.person_id
JOIN publication p
  ON p.id = pp1.publ_id
GROUP BY pp1.person_id, pp2.person_id
ORDER BY pp1.person_id, pp2.person_id;

CREATE UNIQUE INDEX v_graph_by_type_pkey ON v_graph_by_type USING btree (per1_id, per2_id);

--
-- Make a graph based on how long authors have been making publications.
--
CREATE MATERIALIZED VIEW v_graph_by_year
AS
SELECT pp1.person_id AS per1_id,
       pp2.person_id AS per2_id,
       MAX(p.year) - MIN(p.year) + 1 AS weight
FROM person_publication pp1
JOIN person_publication pp2
  ON pp1.publ_id = pp2.publ_id AND pp1.person_id < pp2.person_id
JOIN publication p
  ON p.id = pp1.publ_id
GROUP BY pp1.person_id, pp2.person_id
ORDER BY pp1.person_id, pp2.person_id;

CREATE UNIQUE INDEX v_graph_by_year_pkey ON v_graph_by_year USING btree (per1_id, per2_id);
