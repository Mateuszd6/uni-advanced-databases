Since PostgreSQL is caching the query results (or rather part of the queries),
it's really hard to make a reliable benchmark; after repeating the query it goes
under 8ms on every second and next call. So I provide a MAX value, which is done
on rather cold DB and a MIN value which is significantly smaller due to the
situation I've just mentioned.

I provide the script that first generates a random sample of authors; the first
group is taking all authors who have more than 52 publications, sorting them and
picking 1 for every 400 with equal probability. The second group is just random
100 authors (this will give us many authors with very low number of
publications). The authors are stored in the table and then for each one
benchmarked query is executed and it's result is stored in the benchmarks table.

Then the data in the sheet is just select from benchmark exported to csv.

I provide the 'query time to publication number' chart and 'query time to
publication ranking' (which tells us how many authors have more publication than
the selected one). I also provide the char that displays the difference between
MIN and MAX query result.

I also added a comparison with the query done on the same db, but without
clustering table person_publication which is more than 50% worse in most
cases. I also added a table with the results ran on the warm cache, but they are
bizarrely small compared to the regular results.

The benchmarks are not made on students as it's hard to reliably make a query
on the cold cache. The specification for the machine doing the benchmarks is:
5.2.14-arch2-1-ARCH x86_64, Intel i7-4770K (8) @ 3.900GHz, 8GiB RAM. Which is
not that much RAM, although query result caching still appears to be the thing.
