#include <assert.h>
#define ASSERT assert

#include <cstdio>
#include <cstring>
#include <string>
#include <vector>

#define dbgstr (stderr)

#define OPEN_OUTPUT_FILE(FILEPTR, STREAM, FNAME, HEAD)                  \
    FILE* FILEPTR = fopen(FNAME, "w");                                  \
    fwrite(HEAD.c_str(), HEAD.size(), 1, FILEPTR);                      \
    STREAM = outstream{FILEPTR};                                        \

#define CLOSE_OPENED_FILEPTRS()                                         \
    do {                                                                \
        additional_strm.destroy_safetly();                              \
        citations_strm.destroy_safetly();                               \
        crossrefs_strm.destroy_safetly();                               \
        namealias_strm.destroy_safetly();                               \
        notes_strm.destroy_safetly();                                   \
        persons_strm.destroy_safetly();                                 \
        publication_author_strm.destroy_safetly();                      \
        publication_strm.destroy_safetly();                             \
    } while(0)

static std::string additional_head = "content,publication_id,content_type\n";
static std::string citations_head = "from_key,in_id,label\n";
static std::string crossrefs_head = "from_key,in_id\n";
static std::string namealias_head = "name,person_id\n";
static std::string notes_head = "label,note_type,content,publ_id\n";
static std::string persons_head = "id,key,mdate,name,orcid,bibtex\n";
static std::string publication_author_head = "publ_id,author_key,author_type\n";
static std::string publication_head = "id,key,mdate,title,bibtex,booktitle,isbn,publisher,"
                                       "school,journal,pages,publtype,series,number,"
                                       "volume,month,year,publication_type\n";

static std::string stringify(char const* str);

struct metadata
{
    std::string aux;
    std::string bibtex;
    std::string cdate;
    std::string href;
    std::string key;
    std::string label;
    std::string mdate;
    std::string orcid;
    std::string publtype;
    std::string type;

    void add_attribute(char const* name, char const* value)
    {
        if (strcmp("aux", name) == 0)
            aux = value;
        else if (strcmp("bibtex", name) == 0)
            bibtex = value;
        else if (strcmp("cdate", name) == 0)
            cdate = value;
        else if (strcmp("href", name) == 0)
            href = value;
        else if (strcmp("key", name) == 0)
            key = value;
        else if (strcmp("label", name) == 0)
            label = value;
        else if (strcmp("mdate", name) == 0)
            mdate = value;
        else if (strcmp("orcid", name) == 0)
            orcid = value;
        else if (strcmp("publtype", name) == 0)
            publtype = value;
        else if (strcmp("type", name) == 0)
            type = value;
        else
            fprintf(dbgstr, "ERROR: UNKNOWN ATTR: %s\n", name);
    }
};

struct publication_data
{
    std::string bibtex;
    std::string booktitle;
    std::string isbn;
    std::string publisher;
    std::string school;
    std::string title;
    std::string journal;
    std::string pages;
    std::string publtype;
    std::string series;
    std::string number;
    std::string volume;
    std::string month;
    std::string year;

    void add_store_member(std::string const& name, std::string const& val)
        {
            if (name == "bibtex")
                bibtex = val;
            else if (name == "booktitle")
                booktitle = val;
            else if (name == "isbn")
                isbn = val;
            else if (name == "publisher")
                publisher = val;
            else if (name == "school")
                school = val;
            else if (name == "title")
                title = val;
            else if (name == "journal")
                journal = val;
            else if (name == "pages")
                pages = val;
            else if (name == "publtype")
                publtype = val;
            else if (name == "series")
                series = val;
            else if (name == "number")
                number = val;
            else if (name == "volume")
                volume = val;
            else if (name == "month")
                month = val;
            else if (name == "year")
                year = val;
            // else
            //     fprintf(dbgstr, "ERROR: UNKNOWN FIELD: %s\n", name.c_str());
        }
};

struct insert_value
{
    std::string content;
    bool is_nullable;
    bool is_string;
    bool to_lowercase = false;
};

static int next_publ_id = 1;
static int next_person_id = 1;

std::string get_value(std::string original_content,
                      insert_value* val)
{
    std::string retval{};
    if (val->is_nullable && original_content == "")
        retval = "";
    else
    {
        if (val->is_string)
            retval = "\'";

        if (val->to_lowercase)
        {
            for (size_t i = 0; i < original_content.size(); ++i)
                original_content[i] = tolower(original_content[i]);
        }

        if (val->is_string)
        {
            std::string new_str{};
            for (auto&& i : original_content)
            {
                if (i == '\\')
                {
                    new_str.push_back('\\');
                    new_str.push_back('\\');
                }
                else if (i == '\'')
                {
                    new_str.push_back('\'');
                    new_str.push_back('\'');
                }
                else
                    new_str.push_back(i);
            }

            original_content = std::move(new_str);
        }

        retval += original_content; // TODO: Escape '
        if (val->is_string)
            retval += "\'";
    }

    return retval;
}

#define OUTSTREAM_BUFFER_SIZE (4 * 1024 * 1024)
#define INSTREAM_BUFFER_SIZE (4 * 1024 * 1024)

struct outstream
{
    FILE* dest;

    char* buffer;
    char* curr;
    char const* end;

    outstream() {}

    outstream(FILE* _dest)
    {
        dest = _dest;
        buffer = static_cast<char*>(malloc(OUTSTREAM_BUFFER_SIZE));
        curr = buffer;
        end = buffer + OUTSTREAM_BUFFER_SIZE;
    }

    // Since this is a global varialbe, destructor would cause bad things.
    void destroy_safetly()
    {
        flush();
        free(static_cast<void*>(buffer));
        fclose(dest);
    }

    void flush()
    {
        // fprintf(dbgstr, "FLUSH!\n");
        fwrite(buffer, curr - buffer, 1, dest);
        curr = buffer;
    }

    void write_aux(char const* val, size_t n)
    {
        if (curr + n > end)
            flush();

        // TODO: Handle the case, when n > OUTSTREAM_BUFFER_SIMPLE

        for (char const* p = val; p != val + n; ++p)
            *curr++ = *p;
    }

    void write(int val)
    {
        auto parsed = std::to_string(val);
        write_aux(parsed.c_str(), parsed.size());
    }

    void write(char const* val, bool nullable, bool escape)
    {
        if (nullable && *val == 0)
            return;

        if (escape)
        {
            auto parsed = stringify(val);
            write_aux(parsed.c_str(), parsed.size());
        }
        else
        {
            write_aux(val, strlen(val));
        }
    }

    void write(char c)
    {
        if (curr == end)
            flush();

        *curr++ = c;
    }
};

static outstream additional_strm;
static outstream citations_strm;
static outstream crossrefs_strm;
static outstream namealias_strm;
static outstream notes_strm;
static outstream persons_strm;
static outstream publication_author_strm;
static outstream publication_strm;

struct instream
{
    union
    {
        struct
        {
            char const* str;
            unsigned int size;
            unsigned int idx;
        };
        struct
        {
            FILE* file_star;
            char* buffer;
            char* curr;
            char const* end;
            int eof;
        };
    };
    int stream_type;

    instream()
    {
    }

    ~instream()
    {
    }
};

struct token_and_attrs
{
    int status;

    std::string token_name;
    std::string attrs;
};

struct member
{
    std::string name;
    std::string content;
    metadata meta;
};

static std::string
stringify(char const* str)
{
    std::string retval;
    retval.push_back('\'');
    for (auto p = str; *p; ++p)
    {
        if (*p == '\\')
        {
            retval.push_back('\\');
            retval.push_back('\\');
        }
        else if (*p == '\'')
        {
            retval.push_back('\'');
            retval.push_back('\'');
        }
        else
            retval.push_back(*p);
    }
    retval.push_back('\'');

    return retval;
}

static instream
make_stream(FILE* filestar)
{
    instream retval;
    retval.file_star = filestar;
    retval.stream_type = 0;
    retval.buffer = static_cast<char*>(malloc(INSTREAM_BUFFER_SIZE));
    retval.eof = 0;

    size_t read = fread(retval.buffer, 1, INSTREAM_BUFFER_SIZE, retval.file_star);
    if (read == 0)
        retval.eof = 1;

    retval.curr = retval.buffer;
    retval.end = retval.buffer + read;

    return retval;
}

static instream
make_stream(char const* charstar, unsigned int size)
{
    instream retval;
    retval.str = charstar;
    retval.size = size;
    retval.idx = 0;
    retval.stream_type = 1;

    return retval;
}

static int
instream_getc(instream* str)
{
    if (str->stream_type == 0)
    {
        if (str->eof)
            return EOF;
        else
        {
            if (str->curr == str->end)
            {
                size_t read = fread(str->buffer, 1, INSTREAM_BUFFER_SIZE, str->file_star);
                if (read == 0)
                {
                    str->eof = 1;
                    return EOF;
                }

                str->curr = str->buffer;
                str->end = str->buffer + read;
            }

            return *str->curr++;
        }
    }
    else if (str->idx >= str->size)
        return EOF;
    else
        return str->str[str->idx++];
}

static void
eat_to_start(instream* strm)
{
    char const* start_token = "<dblp>";
    for (int idx = 0; start_token[idx] != 0;)
    {
        char c = instream_getc(strm);
        if (c == start_token[idx])
            ++idx;
        else
            idx = 0;
    }
}

static char
eat_whitespace(instream* strm)
{
    char c;
    while (1)
    {
        c = instream_getc(strm);
        if (!c)
            return c;

        if (c != ' ' && c != '\n' && c != '\r' && c != '\t')
            return c;
    }
}

static std::string
eat_everything_to_token_end(std::string& token_, instream* strm)
{
#if 0
    fprintf(dbgstr, "Eating to endof: %s\n", token_);
#endif

    std::string token = "</";
    std::string so_far = "";
    std::string retval = "";
    token += token_;
    token += ">";

    for (int idx = 0; token[idx] != 0;)
    {
        char c = instream_getc(strm);
        so_far += c;
        if (c == token[idx])
        {
            ++idx;
        }
        else
        {
            idx = 0;
            retval += so_far;
            so_far.clear();
        }
    }

    return retval;
}

static metadata
parse_attributes(char const* att)
{
    metadata retval{};

    for (char const* p = att; *p; ++p)
    {
        if (isspace(*p))
            continue;

        std::string attr_name{};
        std::string attr_value{};
        for (; *p != '='; ++p)
        {
            ASSERT(*p);
            attr_name.push_back(*p);
        }

        p++;
        ASSERT(*p == '"');
        p++;
        while (*p != '"') // TODO: Tolarete backslashed "
        {
            attr_value.push_back(*p);
            p++;
        }

        retval.add_attribute(attr_name.c_str(), attr_value.c_str());
    }

    return retval;
}

static token_and_attrs
parse_next_token(instream* strm)
{
    token_and_attrs retval{};
    char c = eat_whitespace(strm);
    if (!c || c == EOF)
        return token_and_attrs{0, "", ""};

    if (c == '<')
    {
        while ((c = instream_getc(strm)) != '>' && c != ' ' && c != EOF && c)
            retval.token_name.push_back(c);

        if (c != '>')
            while ((c = instream_getc(strm)) != '>')
            {
                retval.attrs.push_back(c);
            }
    }

    if (retval.token_name == "/dblp")
        retval.status = 0;
    else
        retval.status = 1;
    return retval;
}

static std::vector<member>
parse_nested_words(instream* strm)
{
    std::vector<member> retval{};
    for (;;)
    {
        token_and_attrs taa = parse_next_token(strm);
        if (!taa.status)
            return retval;

        std::string content = eat_everything_to_token_end(taa.token_name, strm);
        metadata mtd = parse_attributes(taa.attrs.c_str());

        retval.push_back(member{taa.token_name, content, mtd});
    }
}

static int
parse_word(instream* strm)
{
    token_and_attrs taa = parse_next_token(strm);
    if (!taa.status)
        return taa.status;

    std::string obj_content = eat_everything_to_token_end(taa.token_name, strm);
    metadata mtd = parse_attributes(taa.attrs.c_str());
    instream parse_word_stream = make_stream(obj_content.c_str(), obj_content.size());
    std::vector<member> members = parse_nested_words(&parse_word_stream);
    int publication_id = next_publ_id++;
    publication_data pd{};

    for (auto mem : members)
    {
        pd.add_store_member(mem.name, mem.content);
    }
    auto& title = pd.title;

    // Insert into publication, iif not person record.
    if (taa.token_name != "www" || (title != "Home Page" && title  != ""))
    {
        publication_strm.write(publication_id);
        publication_strm.write(',');
        publication_strm.write(mtd.key.c_str(), false, true);
        publication_strm.write(',');
        publication_strm.write(mtd.mdate.c_str(), false, true);
        publication_strm.write(',');
        publication_strm.write(title.c_str(), false, true);
        publication_strm.write(',');
        publication_strm.write(pd.bibtex.c_str(), true, true);
        publication_strm.write(',');
        publication_strm.write(pd.booktitle.c_str(), true, true);
        publication_strm.write(',');
        publication_strm.write(pd.isbn.c_str(), true, true);
        publication_strm.write(',');
        publication_strm.write(pd.publisher.c_str(), true, true);
        publication_strm.write(',');
        publication_strm.write(pd.school.c_str(), true, true);
        publication_strm.write(',');
        publication_strm.write(pd.journal.c_str(), true, true);
        publication_strm.write(',');
        publication_strm.write(pd.pages.c_str(), true, true);
        publication_strm.write(',');
        publication_strm.write(mtd.publtype.c_str(), true, true);
        publication_strm.write(',');
        publication_strm.write(pd.series.c_str(), true, true);
        publication_strm.write(',');
        publication_strm.write(pd.number.c_str(), true, true);
        publication_strm.write(',');
        publication_strm.write(pd.volume.c_str(), true, true);
        publication_strm.write(',');
        publication_strm.write(pd.month.c_str(), true, true);
        publication_strm.write(',');
        publication_strm.write(pd.year.c_str(), true, false);
        publication_strm.write(',');
        publication_strm.write(taa.token_name.c_str(), false, false);
        publication_strm.write('\n');
    }

    ///
    /// INSERT OTHERS:
    ///
#if 1
    bool not_person_record = taa.token_name != "www" || (title != "Home Page" && title != "");
    int person_id = 0;

    for (auto&& i : members)
    {
        if (i.name == "author" || i.name == "editor")
        {
            if (not_person_record)
            {
                publication_author_strm.write(publication_id);
                publication_author_strm.write(',');
                publication_author_strm.write(i.content.c_str(), false, true);
                publication_author_strm.write(',');
                publication_author_strm.write(i.name.c_str(), false, false);
                publication_author_strm.write('\n');
            }
            else
            {
                if (person_id == 0)
                {
                    person_id = next_person_id++;

                    persons_strm.write(person_id);
                    persons_strm.write(',');
                    persons_strm.write(mtd.key.c_str(), false, true);
                    persons_strm.write(',');
                    persons_strm.write(mtd.mdate.c_str(), false, true);
                    persons_strm.write(',');
                    persons_strm.write(i.content.c_str(), false, true);
                    persons_strm.write(',');
                    persons_strm.write(',');
                    persons_strm.write('\n');
                }
                else
                {
                    namealias_strm.write(i.content.c_str(), false, true);
                    namealias_strm.write(',');
                    namealias_strm.write(person_id);
                    namealias_strm.write('\n');
                }
            }
        }
        else if (i.name == "note" && not_person_record)
        {
            notes_strm.write(i.meta.label.c_str(), false, true);
            notes_strm.write(',');
            notes_strm.write(i.meta.type.c_str(), false, true);
            notes_strm.write(',');
            notes_strm.write(i.content.c_str(), false, true);
            notes_strm.write(',');
            notes_strm.write(publication_id);
            notes_strm.write('\n');
        }
        else if ((i.name == "cdrom" || i.name == "ee" || i.name == "url") && not_person_record)
        {
            additional_strm.write(i.content.c_str(), false, true);
            additional_strm.write(',');
            additional_strm.write(publication_id);
            additional_strm.write(',');
            additional_strm.write(i.name.c_str(), false, false);
            additional_strm.write('\n');
        }
        else if ((i.name == "crossref") && not_person_record)
        {
            crossrefs_strm.write(i.content.c_str(), false, true);
            crossrefs_strm.write(',');
            crossrefs_strm.write(publication_id);
            crossrefs_strm.write('\n');
        }
        else if ((i.name == "cite") && not_person_record)
        {
            citations_strm.write(i.content == "..." ? "" : i.content.c_str(), true, true);
            citations_strm.write(',');
            citations_strm.write(publication_id);
            citations_strm.write(',');
            citations_strm.write(i.meta.label.c_str(), false, true);
            citations_strm.write('\n');
        }
    }

#endif

    return 1;
}

int main(int, char**)
{
    OPEN_OUTPUT_FILE(additional_f, additional_strm, "additional.csv", additional_head);
    OPEN_OUTPUT_FILE(citations_f, citations_strm, "citation.csv", citations_head);
    OPEN_OUTPUT_FILE(crossrefs_f, crossrefs_strm, "crossref.csv", crossrefs_head);
    OPEN_OUTPUT_FILE(namealias_f, namealias_strm, "name_alias.csv", namealias_head);
    OPEN_OUTPUT_FILE(notes_f, notes_strm, "notes.csv", notes_head);
    OPEN_OUTPUT_FILE(persons_f, persons_strm, "persons.csv", persons_head);
    OPEN_OUTPUT_FILE(publication_author_f, publication_author_strm, "publication_author.csv", publication_author_head);
    OPEN_OUTPUT_FILE(publication_f, publication_strm, "publication.csv", publication_head);

    instream input = make_stream(stdin);
    eat_to_start(&input);
    while (parse_word(&input))
    {
    }

    CLOSE_OPENED_FILEPTRS();

    return 0;
}
