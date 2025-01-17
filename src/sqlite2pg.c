/*
 * src/sqlite2pg.c
 */
#include "postgres.h"

#include <ctype.h>

# include "common/keywords.h"
# include "utils/builtins.h"
# include "utils/array.h"
# include "pgtypes.h"

// #include "parser/parse_type.h"
// #include "parser/scansup.h"
// #include "catalog/pg_type.h"
// #include "common/int.h"
// #include "lib/qunique.h"
// #include "miscadmin.h"
// #include "tsearch/ts_locale.h"
// #include "utils/guc.h"
// #include "utils/lsyscache.h"
// #include "utils/memutils.h"
// #include "utils/pg_crc.h"

#include "sqlite_driver/sqlite3.h"
#include "sqlite_wrapper.h"

PG_MODULE_MAGIC;
#define TEXTOID 25


PG_FUNCTION_INFO_V1(test_c);
PG_FUNCTION_INFO_V1(connect_sqlite);

PG_FUNCTION_INFO_V1(is_legal_colname);
PG_FUNCTION_INFO_V1(get_sqlite_tables_c);
// PG_FUNCTION_INFO_V1(get_sqlite_columns);
// PG_FUNCTION_INFO_V1(sqlite_rowid_exists);
// PG_FUNCTION_INFO_V1(generate_create_table);
// PG_FUNCTION_INFO_V1(sqlite2pg_typemap);
// PG_FUNCTION_INFO_V1(mirgate_single_table);
// PG_FUNCTION_INFO_V1(mirgate_sqlite2pg);

// PG_FUNCTION_INFO_V1(__create_sqlite2pg_status);
// PG_FUNCTION_INFO_V1(__insert_sqlite2pg_status);
// PG_FUNCTION_INFO_V1(__update_sqlite2pg_status);

/*
 * Prototypes for private functions
 */
static bool is_reserved_keyword(const char *word);
static sqlite_tablename *get_sqlite_tablenames(sqlite3 *db);

Datum
is_legal_colname(PG_FUNCTION_ARGS)
{
    char *name = text_to_cstring(PG_GETARG_TEXT_PP(0));

    PG_RETURN_BOOL(is_reserved_keyword(name));
}

Datum
get_sqlite_tables_c(PG_FUNCTION_ARGS)
{
    char *sqlite_path = text_to_cstring(PG_GETARG_TEXT_PP(0));
    sqlite3 *db = connect2sqlite(sqlite_path);
    sqlite_tablename *tables = get_sqlite_tablenames(db);
    Datum *texts = palloc0(sizeof(Datum) * tables->n_tables);
    ArrayType *result;

    for(int i = 0; i < tables->n_tables; ++i)
    {
        texts[i] = CStringGetTextDatum(tables->table_names[i]);
    }

    result = construct_array(texts, tables->n_tables, TEXTOID, -1, false, 'i');
    // Datum texts[2];
    // ArrayType *result;

    // texts[0] = CStringGetTextDatum("Hello");
    // texts[1] = CStringGetTextDatum("World");    

    // result = construct_array(texts, 2, TEXTOID, -1, false, 'i');

    PG_RETURN_ARRAYTYPE_P(result);
}

Datum
test_c(PG_FUNCTION_ARGS)
{
    PG_RETURN_INT32(10086);
}

Datum
connect_sqlite(PG_FUNCTION_ARGS)
{
    // char *sqlite_path = text_to_cstring(PG_GETARG_TEXT_PP(0));
    char *sqlite_path = "/home/zhouzhiqiang/filedir/diff_statistic___1735279393_Y2hZMm88.db";
    sqlite3 *db;
    char *error_message = NULL;
    int rc;
    sqlite_query_result *result;

    result = init_sqlite_query_result();

    db = connect2sqlite(sqlite_path);
    char *sql = "select * from sqlite_master limit 5;";

    rc = sqlite3_exec(db, sql, sqlite_rows_callback, (void *)result, &error_message);
    if(rc != SQLITE_OK)
    {
        elog(ERROR, "SQL error: %s", error_message);
        sqlite3_free(error_message);
    }

    elog(NOTICE, "result: %d", result->n_columns);
    for(int i = 0; i < result->n_columns; ++i)
        elog(NOTICE, "result: %s", result->column_names[i]);
    
    sqlite_row *curr_row = result->head;
    // elog(NOTICE, "result: %d", result->n_rows);

    for(int i = 0; i < result->n_rows; ++i)
    {
        for(int j = 0; j < curr_row->length; ++j)
            elog(NOTICE, "result[%d][%d]: %s", i, j, curr_row->values[j]);
        curr_row = curr_row->next;
    }

    free_sqlite_query_result(result);
    sqlite3_close(db);
    return 0;
}

bool
is_reserved_keyword(const char *word)
{
    // char *name = text_to_cstring(PG_GETARG_TEXT_PP(0));
    int kwnum = ScanKeywordLookup(word, &ScanKeywords);

    if (kwnum >= 0 && ScanKeywordCategories[kwnum] != UNRESERVED_KEYWORD)
        return true;

    return false;
}

static sqlite_tablename *
get_sqlite_tablenames(sqlite3 *db)
{
    char *sql = "select name from sqlite_master where type='table' order by name;";
    sqlite_query_result *result = init_sqlite_query_result();
    int rc;
    char *error_message = NULL;
    int i;
    sqlite_row *curr_row = NULL;
    char **tablename = NULL;
    sqlite_tablename *ret = (sqlite_tablename *)palloc(sizeof(sqlite_tablename));

    rc = sqlite3_exec(db, sql, sqlite_rows_callback, (void *)result, &error_message);
    if(rc != SQLITE_OK)
    {
        // elog Error will directly cause the process to exit
        // this may cause memory leak.
        // copy error_message by pstrdup, then free it.
        char *err_msg_ctx = pstrdup(error_message);
        sqlite3_free(error_message);
        elog(ERROR, "SQL error: %s", err_msg_ctx);
    }

    tablename = (char **)palloc(sizeof(char *) * result->n_rows);

    curr_row = result->head;
    for(i = 0; i < result->n_rows; ++i)
    {
        Assert(curr_row != NULL);
        Assert(curr_row->values != NULL);
        Assert(curr_row->values[0] != NULL);

        tablename[i] = pstrdup(curr_row->values[0]);
        // elog(NOTICE, "tablename: %s", curr_row->values[0]);
        curr_row = curr_row->next;
    }

    ret->n_tables = result->n_rows;
    ret->table_names = tablename;
    free_sqlite_query_result(result);

    return ret;
}
