\set searched_author '''Krzysztof Diks'''
WITH searched_author AS (
  (SELECT per.id as id
   FROM namealias n
   JOIN person per
     ON per.id = n.person_id
   WHERE n.name = :searched_author)
  UNION
    (SELECT id as id
     FROM person per
     WHERE per.name = :searched_author)
  LIMIT 1
)
SELECT publ.year,
       publ.title,
       publ.publication_type,
       pp.autor_type,
       (SELECT STRING_AGG(_per.name, ', ' ORDER BY _per.name)
        FROM person_publication _pp
        JOIN person _per
          ON _per.id = _pp.person_id
        WHERE _pp.publ_id = publ.id
        GROUP BY _pp.publ_id) AS authors
FROM searched_author
JOIN person_publication pp
  ON pp.person_id = searched_author.id
JOIN publication publ
  ON publ.id = pp.publ_id
JOIN person per
  ON per.id = pp.person_id
ORDER BY publ.year DESC;
