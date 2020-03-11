DROP TABLE IF EXISTS tmp_person_publ;
DROP TABLE IF EXISTS tmp_crossref;
DROP TABLE IF EXISTS tmp_citation;

\i drop.sql
\i create.sql

CREATE table tmp_person_publ(
    id BIGSERIAL NOT NULL,
    publ_id BIGINT NOT NULL REFERENCES publication (id),
    author_key VARCHAR NOT NULL,
    author_type author_t NOT NULL,

    PRIMARY KEY (author_key, publ_id, id)
);

CREATE table tmp_crossref(
    from_key VARCHAR NOT NULL REFERENCES publication(key),
    in_id BIGINT NOT NULL REFERENCES publication(id),

    PRIMARY KEY (from_key, in_id)
);

CREATE table tmp_citation(
    id BIGSERIAL NOT NULL,
    from_key VARCHAR REFERENCES publication(key),
    in_id BIGINT NOT NULL REFERENCES publication(id),
    label VARCHAR NOT NULL,

    PRIMARY KEY (id)
);

\copy publication (id,key,mdate,title,bibtex,booktitle,isbn,publisher,school,journal,pages,publtype,series,number,volume,month,year,publication_type) FROM ./parser/publication.csv QUOTE '''' DELIMITER ',' CSV HEADER

\copy note (label,note_type,content,publ_id) FROM ./parser/notes.csv QUOTE '''' DELIMITER ',' CSV HEADER

\copy additional_content (content,publication_id,content_type) FROM ./parser/additional.csv QUOTE '''' DELIMITER ',' CSV HEADER

\copy person (id,key,mdate,name,orcid,bibtex) FROM ./parser/persons.csv QUOTE '''' DELIMITER ',' CSV HEADER

\copy namealias (name,person_id) FROM ./parser/name_alias.csv QUOTE '''' DELIMITER ',' CSV HEADER

\copy tmp_person_publ (publ_id,author_key,author_type) FROM ./parser/publication_author.csv QUOTE '''' DELIMITER ',' CSV HEADER

\copy tmp_crossref (from_key,in_id) FROM ./parser/crossref.csv QUOTE '''' DELIMITER ',' CSV HEADER

\copy tmp_citation (from_key,in_id,label) FROM ./parser/citation.csv QUOTE '''' DELIMITER ',' CSV HEADER


INSERT INTO person_publication(
    person_id,
    publ_id,
    autor_type
)
SELECT per.id, pid.id, pp.author_type
FROM publication pid
JOIN tmp_person_publ pp
    ON pp.publ_id = pid.id
JOIN person per
    ON per.name = pp.author_key
ON CONFLICT DO NOTHING;

INSERT INTO person_publication(
    person_id,
    publ_id,
    autor_type
)
SELECT per.id, pid.id, pp.author_type
FROM publication pid
JOIN tmp_person_publ pp
    ON pp.publ_id = pid.id
JOIN namealias n
    ON pp.author_key = n.name
JOIN person per
    ON per.id = n.person_id
ON CONFLICT DO NOTHING;

INSERT INTO crossref(
    from_id,
    in_id
)
SELECT p.id, c.in_id
FROM tmp_crossref c
JOIN publication p
   ON p.key = c.from_key;

INSERT INTO citation(
    label,
    from_id,
    in_id
)
SELECT c.label, p.id, c.in_id
FROM tmp_citation c
LEFT OUTER JOIN publication p
   ON p.key = c.from_key;

-- Drop temporary tables.
DROP TABLE IF EXISTS tmp_person_publ;
DROP TABLE IF EXISTS tmp_crossref;
DROP TABLE IF EXISTS tmp_citation;
