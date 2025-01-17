/*
 * src/sqlite2pg.c
 */
#include "postgres.h"

#include <ctype.h>

# include "common/keywords.h"
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


PG_FUNCTION_INFO_V1(test_c);
PG_FUNCTION_INFO_V1(connect_sqlite);

PG_FUNCTION_INFO_V1(is_keyword);
// PG_FUNCTION_INFO_V1(get_sqlite_tables);
// PG_FUNCTION_INFO_V1(get_sqlite_columns);
// PG_FUNCTION_INFO_V1(sqlite_rowid_exists);
// PG_FUNCTION_INFO_V1(generate_create_table);
// PG_FUNCTION_INFO_V1(sqlite2pg_typemap);
// PG_FUNCTION_INFO_V1(mirgate_single_table);
// PG_FUNCTION_INFO_V1(mirgate_sqlite2pg);

// PG_FUNCTION_INFO_V1(__create_sqlite2pg_status);
// PG_FUNCTION_INFO_V1(__insert_sqlite2pg_status);
// PG_FUNCTION_INFO_V1(__update_sqlite2pg_status);

Datum
is_keyword(PG_FUNCTION_ARGS)
{
    const char *name = text_to_cstring(PG_GETARG_TEXT_PP(0));
    elog(NOTICE, "keyword: %s", name);
    int kwnum = ScanKeywordLookup(name, &ScanKeywords);


    if (kwnum >= 0 && ScanKeywordCategories[kwnum] != UNRESERVED_KEYWORD)
        PG_RETURN_BOOL(true);

    PG_RETURN_BOOL(false);
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


