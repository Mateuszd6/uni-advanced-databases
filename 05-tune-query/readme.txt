I provide benchmarks for the version of DB with no other indexes that default
ones taken from constraints when creating databse, and four optimizations,
described below:

Optimizations:
1. Basic index on person_publication table, as this was the part of the query
   that made it quadratic. (Hudge speedup, as expected)
2. Change btrees to hashes for the VARCHAR columns (name column in person and
   namealias). (Minor, unnoticable speedup)
3. Cluster person_publication on (publication, person) - this allows us to have
   a better cache locallity when searching for authors to aggregate (noticable
   speedup)
4. Materialized view that allows us to skip aggregating authors completely
   (crazy speedup).

The sql for these benchmarks is provided in the query.sql file.

The speed of INSERTing into the tables with additional indexes (specially
person_publication) is lower than the base case, but the differences are not
major and are surely worth over 10x speedup on SELECT. Of course the version
with MATERIALIZED VIEW is not refreshed after each INSERT so the data displayed
in that case is inaccurate.

Benchmarking:
I run 10 queries (procedure run_benchmark in psql). Each benchmark
takes the same sample of authors and makes the get_publ_for_author query on them
(for each benchmark authors are queried in different, random order). The first
one is discarded, as we are benchmarking on the warm chache. The rest is stored
in the benchmark table and from them output is generated.
