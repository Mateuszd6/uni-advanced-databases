-- Mateusz Dudziński (md394171).

CREATE TYPE publ_t AS enum(
    'article',
    'book',
    'incollection',
    'inproceedings',
    'mastersthesis',
    'phdthesis',
    'proceedings',
    'www');

CREATE TYPE author_t AS enum(
    'author',
    'editor');

CREATE TYPE additional_content_t AS enum(
    'cdrom',
    'ee',
    'url');

CREATE TYPE month_t AS enum(
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december');

CREATE TABLE publication (
    id BIGSERIAL NOT NULL,
    key VARCHAR UNIQUE NOT NULL,
    mdate TIMESTAMP NOT NULL,
    title VARCHAR NOT NULL,
    bibtex VARCHAR,
    booktitle VARCHAR,
    isbn VARCHAR,
    publisher VARCHAR,
    school VARCHAR,
    journal VARCHAR,
    pages VARCHAR,
    publtype VARCHAR,
    series VARCHAR,
    number VARCHAR,
    volume VARCHAR,
    month VARCHAR,
    year SMALLINT,

    publication_type publ_t NOT NULL,

    PRIMARY KEY (id)
);

CREATE TABLE additional_content (
    id BIGSERIAL NOT NULL,
    content VARCHAR NOT NULL,

    publication_id BIGINT NOT NULL,
    content_type additional_content_t NOT NULL,

    PRIMARY KEY (id),

    CONSTRAINT additional_content_publication_id_fkey FOREIGN KEY (publication_id)
    REFERENCES publication (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE
);

-- Basically publication to publication table for cross references.  The
-- difference between citation and crossref is that one can citate mutliple
-- times another publication in his work, but crossref appears at most once.
CREATE TABLE crossref (
    from_id BIGINT NOT NULL,
    in_id BIGINT NOT NULL,

    PRIMARY KEY (in_id, from_id),

    CONSTRAINT crossref_from_id_fkey FOREIGN KEY (from_id)
    REFERENCES publication (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE,

    CONSTRAINT crossref_in_id_fkey FOREIGN KEY (in_id)
    REFERENCES publication (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE
);

CREATE TABLE citation (
    id BIGSERIAL NOT NULL,
    label VARCHAR NOT NULL,
    from_id BIGINT,
    in_id BIGINT NOT NULL,

    PRIMARY KEY (id),

    CONSTRAINT citation_from_id_fkey FOREIGN KEY (from_id)
    REFERENCES publication (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE,

    CONSTRAINT citation_in_id_fkey FOREIGN KEY (in_id)
    REFERENCES publication (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE
);

CREATE TABLE note (
    id BIGSERIAL NOT NULL,
    label VARCHAR,
    note_type VARCHAR,
    content VARCHAR NOT NULL,

    publ_id BIGINT NOT NULL,

    PRIMARY KEY (id),

    CONSTRAINT note_publ_id_fkey FOREIGN KEY (publ_id)
    REFERENCES publication (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE
);

CREATE TABLE person (
    id BIGSERIAL NOT NULL,
    key VARCHAR UNIQUE NOT NULL,
    mdate TIMESTAMP NOT NULL,
    name VARCHAR UNIQUE NOT NULL, -- person aliases stored in namealias table.
    orcid VARCHAR,
    bibtex VARCHAR,

    PRIMARY KEY (id)
);

-- CREATE INDEX person_idx
-- ON person (publ_id, author_key);

-- In dblp the person record (which is actually www record with title set to
-- 'HomePage'), can contain mutliple names. First are the primary ones, rest are
-- used as aliases, and here I store them in this column.
CREATE TABLE namealias (
    id BIGSERIAL NOT NULL,
    name VARCHAR NOT NULL,

    person_id BIGINT NOT NULL,

    -- Pair (name, person_id) could be PK, but making PK on a pair that contains
    -- VARCHAR is rather inefficient.
    PRIMARY KEY (id),
    UNIQUE (name, person_id),

    CONSTRAINT namealias_person_id_fkey FOREIGN KEY (person_id)
    REFERENCES person (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE
);

CREATE TABLE person_publication (
    person_id BIGINT NOT NULL,
    publ_id BIGINT NOT NULL,
    autor_type author_t NOT NULL,

    -- I assume that one person can't be author and the editor of the same
    -- publication, that's why author is not part of the PK.
    PRIMARY KEY (publ_id, person_id),

    CONSTRAINT person_publication_person_id_fkey FOREIGN KEY (person_id)
    REFERENCES person (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE,

    CONSTRAINT person_publication_publ_id_fkey FOREIGN KEY (publ_id)
    REFERENCES publication (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE
);
