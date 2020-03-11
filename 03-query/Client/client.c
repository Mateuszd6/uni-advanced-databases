// Define connection properties. Must _NOT_ use parents, as preproc must concat
// them to make something like connection string.
#define PQ_USERNAME "mateusz"
#define PQ_DBNAME "zbd"
#define PQ_PASSWORD "x"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <libpq-fe.h>

#define STR_EQUAL(STR_1, STR_2) (strcmp(STR_1, STR_2) == 0)

#define USE_COLORS (1)

static char const* ctext_article = "Journal Articles";
static char const* ctext_book_or_theses = "Books and Theses";
static char const* ctext_parts_in_books = "Parts in Books and Collections";
static char const* ctext_conference = "Conference";
static char const* ctext_editorship = "Editorship";
static char const* ctext_other = "Other";

static int sett_use_colors = 1;
static int sett_use_utf_bullets = 1;
static char const* sett_name_to_search = "Krzysztof Diks";

#define COLOR_RESET (color[0])
#define COLOR_BLACK (color[1])
#define COLOR_RED (color[2])
#define COLOR_GREEN (color[3])
#define COLOR_YELLOW (color[4])
#define COLOR_BLUE (color[5])
#define COLOR_PURPLE (color[6])
#define COLOR_TURQUISE (color[7])
#define COLOR_BRIGHT_BLACK (color[8])
#define COLOR_BRIGHT_RED (color[9])
#define COLOR_BRIGHT_GREEN (color[10])
#define COLOR_BRIGHT_YELLOW (color[11])
#define COLOR_BRIGHT_BLUE (color[12])
#define COLOR_BRIGHT_PURPLE (color[13])
#define COLOR_BRIGHT_TURQUISE (color[14])

static char const* color[] = {
    "\e[0m",
    "\e[30m", "\e[31m", "\e[32m", "\e[33m", "\e[34m", "\e[35m", "\e[36m",
    "\e[30;1m", "\e[31;1m", "\e[32;1m", "\e[33;1m", "\e[34;1m", "\e[35;1m", "\e[36;1m"
};

static char const* publications_query =
    "WITH searched_author AS ( "
    "  (SELECT per.id as id "
    "   FROM namealias n "
    "   JOIN person per "
    "   ON per.id = n.person_id "
    "   WHERE n.name = $1) "
    "  UNION "
    "  (SELECT id as id "
    "   FROM person per "
    "   WHERE per.name = $1) "
    "  LIMIT 1 "
    ") "
    "SELECT publ.year, "
    "     publ.title, "
    "     publ.publication_type AS ptype, "
    "     pp.autor_type AS atype, "
    "     (SELECT STRING_AGG(_per.name, ', ' ORDER BY _per.name) "
    "      FROM person_publication _pp "
    "      JOIN person _per "
    "      ON _per.id = _pp.person_id "
    "      WHERE _pp.publ_id = publ.id "
    "      GROUP BY _pp.publ_id) AS authors "
    "FROM searched_author "
    "JOIN person_publication pp "
    "  ON pp.person_id = searched_author.id "
    "JOIN publication publ "
    "  ON publ.id = pp.publ_id "
    "JOIN person per "
    "  ON per.id = pp.person_id "
    "ORDER BY publ.year DESC; ";

static void
die_nicely(PGconn *conn)
{
    PQfinish(conn);
    exit(1);
}

// Holds a reference to the string and a color in which it should be printed.
struct colored_string
{
    char const* str;
    char const* color_code;
};

static struct colored_string
publtype_authortype_tostr(char const* authortype, char const* publtype)
{
    char const* str = ctext_other;
    char const* color_code = 0;

    if (STR_EQUAL(authortype, "editor"))
    {
        str = ctext_editorship;
        color_code = COLOR_BRIGHT_TURQUISE;
    }
    else if (STR_EQUAL(authortype, "author"))
    {
        if (STR_EQUAL(publtype, "article"))
        {
            str = ctext_article;
            color_code = COLOR_BRIGHT_RED;
        }
        else if (STR_EQUAL(publtype, "book")
                 || STR_EQUAL(publtype, "mastersthesis")
                 || STR_EQUAL(publtype, "phdthesis"))
        {
            str = ctext_book_or_theses;
            color_code = COLOR_BRIGHT_YELLOW;
        }
        else if (STR_EQUAL(publtype, "proceedings")
                 || STR_EQUAL(publtype, "inproceedings"))
        {
            str = ctext_conference;
            color_code = COLOR_BRIGHT_BLUE;
        }
        else if (STR_EQUAL(publtype, "incollection"))
        {
            str = ctext_parts_in_books;
            color_code = COLOR_BRIGHT_BLUE;
        }
    }

    struct colored_string retval;
    retval.str = str;
    retval.color_code = sett_use_colors ? color_code : 0;
    return retval;
}

static void
display_result(PGresult *res)
{
    char const* currentYear = 0;

    // Use PQfnumber to avoid assumptions about field order in result
    for (int i = 0; i < PQntuples(res); i++)
    {
        if (i != 0)
            printf("\n");

        // Get the field values.
        char const* year = PQgetvalue(res, i, PQfnumber(res, "year"));
        char const* title = PQgetvalue(res, i, PQfnumber(res, "title"));
        char const* ptype = PQgetvalue(res, i, PQfnumber(res, "ptype"));
        char const* atype = PQgetvalue(res, i, PQfnumber(res, "atype"));
        char const* authors = PQgetvalue(res, i, PQfnumber(res, "authors"));
        struct colored_string cstring = publtype_authortype_tostr(atype, ptype);

        if (!currentYear || !STR_EQUAL(currentYear, year))
        {
            printf("[%s]\n", year);
            currentYear = year;
        }

        printf("  %s\u25a0 [%s]\n   %s %s\n    %s\n",
               cstring.color_code ? cstring.color_code : "",
               cstring.str,
               cstring.color_code ? "\e[0m" : "",
               authors,
               title);
    }
}

static void
die_if_failed_query(PGconn* conn, PGresult* res, ExecStatusType expected_result)
{
    if (PQresultStatus(res) != expected_result)
    {
        fprintf(stderr, "QUERY failed: %s", PQerrorMessage(conn));
        PQclear(res);
        die_nicely(conn);
    }
}

static void
usage(char const* pname)
{
    fprintf(stderr, "usage: %s [--no-color] [--no-utf-bullets] person-to-search\n", pname);
    exit(1);
}

int
main(int argc, char** argv)
{
    for (int i = 1; i < argc; ++i)
    {
        if (STR_EQUAL(argv[i], "--no-color"))
        {
            sett_use_colors = 0;
        }
        else if (STR_EQUAL(argv[i], "--no-utf-bullets"))
        {
            sett_use_utf_bullets = 0;
        }
        else
        {
            static int name_set = 0;
            if (name_set != 0)
                usage(argv[0]);

            sett_name_to_search = argv[i];
            name_set = 1;
        }
    }

    char const* conninfo = "user=" PQ_USERNAME " password=" PQ_PASSWORD " dbname=" PQ_DBNAME;

    // Make a connection to the database
    PGconn* conn = PQconnectdb(conninfo);
    if (PQstatus(conn) != CONNECTION_OK)
    {
        fprintf(stderr, "Connection to database failed: %s", PQerrorMessage(conn));
        die_nicely(conn);
    }

    // Set up parameters.
    char const* paramValues[1];
    paramValues[0] = sett_name_to_search;

#if 1
    PGresult* prepare_result = PQprepare(conn, "person_query", publications_query, 1, 0);
    die_if_failed_query(conn, prepare_result, PGRES_COMMAND_OK);
    PQclear(prepare_result);

    PGresult* publ_query = PQexecPrepared(conn, "person_query", 1, paramValues, 0, 0, 0);
    die_if_failed_query(conn, publ_query, PGRES_TUPLES_OK);

#else
    PGresult* publ_query = PQexecParams(conn, publications_query, 1, 0, paramValues, 0, 0, 0);
    die_if_failed_query(conn, publ_query, PGRES_TUPLES_OK);
#endif


    display_result(publ_query);
    PQclear(publ_query);
    PQfinish(conn);

    return 0;
}
