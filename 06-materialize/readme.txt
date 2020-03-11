There are 234247 publications added after 01-09-2019. All publications and
person_publication records are stored in the tables publ_to_add and
person_publ_to_add. The benchmark procedure is just inserting from these tables
into the main ones.

VOL 0: No views, just the database with all indexes set up.

VOL 1: Names aggregation view (v_publ_author_names):
  Just stores aggregation of author names to avoid STRING_AGG on every get.
  + Space increase: 409 MB
  + Build time: 02:22.880

VOL 2: Total publication view (v_publ_author_total):
  Stores all publication data. This stores (redundantly) all fields of
    publication along with the aggregated author names. This takes a bit more size
    and the gain is not so great but it is faster.
  + Space increase: 947 MB
  + Build time: 02:36.475

VOL 3: Cache query as JSON (v_person_ready_query):
  For each person, query for his/her _all_ publication is stored as a single
    json field. The whole response is in just one column which allows this query
    to go insanely fast. On the other hand rebuild takes a lot of time (JSON
    aggregations cost some time in PSQL) and takes a lot of space (2.2G if all
    authors have their publications in cache table). Also, when adding a new
    publication all related authors must have their queries rebuilt, which takes
    time.
  + Space increase: 2223 MB
  + Build time: 10:22.846


Functions that updates the database by inserting a record from precoputed tables
to the main ones are:
  * insert_one
  * insert_one_update_names_view
  * insert_one_update_total_view
  * insert_one_update_ready_view

They (in transaction) insert a publication record, insert person_publication
records and if needed update required views. Charts display times for a single
insert and a total time of a stress test, which is 10K inserts incrementally
updating all views one-after-another.

The results suggest that  it is not worth to incrementally  update the last view
because it takes  just too much time.  Also it could be store  in something else
than a  table in relational  DB, possibly a nosql  database like redis  would be
better as it does  not have to be joined with anything and  can be updated every
few hours.
