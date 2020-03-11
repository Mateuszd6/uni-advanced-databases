-- Mateusz Dudziński (md394171).

CREATE TABLE paper_type (
    id INT NOT NULL,
    name VARCHAR(28) NOT NULL,

    PRIMARY KEY (id)
);

CREATE TABLE author_type (
    id INT NOT NULL,
    name VARCHAR(28) UNIQUE NOT NULL,

    PRIMARY KEY (id)
);

CREATE TABLE additional_content_type (
    id INT NOT NULL,
    name VARCHAR(28) UNIQUE NOT NULL,

    PRIMARY KEY (id)
);

CREATE TABLE publication (
    id BIGSERIAL NOT NULL,
    key VARCHAR UNIQUE NOT NULL,
    mdate TIMESTAMP NOT NULL,
    title VARCHAR,
    booktitle VARCHAR,
    isbn VARCHAR,
    publisher VARCHAR,
    school VARCHAR,
    journal VARCHAR,
    pages VARCHAR,
    publtype VARCHAR,
    series VARCHAR,
    number INT,
    volume INT,
    month SMALLINT,
    year SMALLINT,

    paper_type_id INT NOT NULL,

    PRIMARY KEY (id),

    CONSTRAINT publication_paper_type_id_fkey FOREIGN KEY (paper_type_id)
    REFERENCES paper_type (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
);

CREATE TABLE additional_content (
    id BIGSERIAL NOT NULL,
    content VARCHAR NOT NULL,

    publication_id BIGINT NOT NULL,
    content_type_id INT NOT NULL,

    PRIMARY KEY (id),

    CONSTRAINT additional_content_content_type_id_fkey FOREIGN KEY (content_type_id)
    REFERENCES additional_content_type (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION,

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

    PRIMARY KEY (from_id, in_id),

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
    content VARCHAR NOT NULL,

    from_id BIGINT NOT NULL,
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
    key VARCHAR UNIQUE NOT NULL,
    mdate TIMESTAMP NOT NULL,
    content VARCHAR,

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
    name VARCHAR NOT NULL, -- person aliases stored in namealias table.
    orcid VARCHAR,

    PRIMARY KEY (id)
);

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
    author_type_id INT NOT NULL,

    -- I assume that one person can't be author and the editor of the same
    -- publication, that's why author_type_id is not part of the PK.
    PRIMARY KEY (person_id, publ_id),

    CONSTRAINT person_publication_person_id_fkey FOREIGN KEY (person_id)
    REFERENCES person (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE,

    CONSTRAINT person_publication_publ_id_fkey FOREIGN KEY (publ_id)
    REFERENCES publication (id) MATCH SIMPLE
    ON UPDATE CASCADE
    ON DELETE CASCADE,

    CONSTRAINT person_publication_author_type_id_fkey FOREIGN KEY (author_type_id)
    REFERENCES author_type (id) MATCH SIMPLE
    ON UPDATE NO ACTION
    ON DELETE NO ACTION
);

-- These are contant enumeration values.
INSERT INTO author_type (
    id,
    name
) VALUES
    (1, 'Author'),
    (2, 'Editor');

INSERT INTO paper_type (
    id,
    name
) VALUES
    (1, 'Article'),
    (2, 'Book'),
    (3, 'Incollection'),
    (4, 'Inproceedings'),
    (5, 'Mastersthesis'),
    (6, 'Phdthesis'),
    (7, 'Proceedings'),
    (8, 'Www');

INSERT INTO additional_content_type (
    id,
    name
) VALUES
    (1, 'CDROM'),
    (2, 'EE'),
    (3, 'URL');
