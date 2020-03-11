ZBD importing DBLP
Mateusz Dudziński


1 Parser:
═════════

  The parser is written in C++ (I would rather write in plain C, but I had no time).
  Its source and a Makefile in directory ./parser. It takes only one argument
  which is a path to the dblp.xml file and writes csv files for all tables. In
  order to avoid joining the data in the program it sometimes writes some
  temporary tables which are now imported into proper ones on import, for
  example, person_publication is stored as publication_id + person_name and
  then, after importing both publication and person tables to server, this data
  is joined and written to proper table.


2 run.sql:
══════════

  This script drops the table, runs create script and then performs import
  procedure as mentioned above.


3 Model changes:
════════════════

  • Changed "id + name" tables (like publication_type to enums) for easier code.
  • Fixed some parameters which came out during parsing, eg. month is now
    a varchar due to some strange cases like month being 'October/December'.
  • Fixed some PKs.


4 Table counts and sizes:
═════════════════════════

  • publication: 4786933 (1257 MB)
  • person: 2369922 (512 MB)
  • namealias: 55206 (8432 kB)
  • note: 33304 (4008 kB)
  • additional_content: 10330902 (1199 MB)
  • person_publication: 14308594 (1426 MB)
  • citation: 172576 (13 MB)
  • crossref: 2535511 (207 MB)
  Total: 4636 MB (All temporary tables when importing data take about ~3GB)


5 Timings:
══════════

  • Parse: 1m 19s
  • Import (run.sql): 24m 14s
    ⁃ COPY:
      ‣ publication: 1m 1s
      ‣ person: 39s
      ‣ namealias: 1s
      ‣ note: 1s
      ‣ additional_content: 1m 37s
      ‣ tmp_person_publ: 5m 06s
      ‣ tmp_citation: 4s
      ‣ tmp_crossref: 1m 06s
    ⁃ INSERT:
      ‣ person_publication (no alias): 12m 56s (??)
      ‣ person_publication (w. alias): 43s
      ‣ crossref: 56s
      ‣ citation: 4s


6 Feedback:
═══════════

  The data was rough which reflected the import procedure pretty heavily
  (duplicate pairs person_publication etc). In some places I had to use ON
  CONFLICTS DO NOTHING to avoid more queries in order to prepare data (in most
  cases the conflicts are because of duplications). I still think that joining
  the tables on server side not on parse time was a good idea, although
  person-publication query takes a lot of time. I don't how to make it faster
  (the original version was even slower). The problem is that author_key is not
  referencing person(name), because it also contains names that are not stored
  in person table (like aliases).

  Everything was done on i7-4770K 3.5Ghz Linux with postresql 11.5 and clang 8.
