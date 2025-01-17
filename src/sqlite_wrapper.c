/*
 * src/sqlite_wrapper.c
 */

# include "sqlite_wrapper.h"

sqlite_query_result *
init_sqlite_query_result()
{
    sqlite_query_result *result = (sqlite_query_result *)palloc(sizeof(sqlite_query_result));

    result->n_columns = 0;
    result->n_rows = 0;
    result->column_names = NULL;
    result->head = NULL;
    result->end = NULL;

    return result;
};

void
sqlite_rows_append(sqlite_query_result *result, sqlite_row *new_row)
{
    Assert(result != NULL);

    result->n_rows++;

    if (result->head == NULL)
        result->head = new_row;
    else
        result->end->next = new_row;
    result->end = new_row;

    return;
}

void
free_sqlite_query_result(sqlite_query_result *result)
{
    sqlite_row *current = NULL;

    if(result == NULL)
        return;

    // free column names
    if (result->column_names != NULL)
        for (int i = 0; i < result->n_columns; i++)
            pfree(result->column_names[i]);
    pfree(result->column_names);

    // free rows
    current = result->head;
    while (current != NULL)
    {
        sqlite_row *tmp = current->next;
        pfree(current);
        current = tmp;
    }

    // free result
    pfree(result);

    return;
}

int
sqlite_rows_callback(void *result, int argc, char **argv, char **azColName)
{
    sqlite_query_result *res = (sqlite_query_result *)result;
    sqlite_row *row = (sqlite_row *)palloc0(sizeof(sqlite_row));
    int i;

    if(res == NULL)
        return 0;
    
    // column names are only set once
    if(res->column_names == NULL)
    {
        res->column_names = (char **)palloc0(sizeof(char *) * argc);
        res->n_columns = argc;
        for(i = 0; i < argc; i++)
        {
            if(azColName[i] == NULL)
                continue;
            res->column_names[i] = pstrdup(azColName[i]);
        }
    }

    // add row to result
    row->length = argc;
    row->values = (char **)palloc0(sizeof(char *) * argc);
    for(i = 0; i < argc; i++)
    {
        if(argv[i] == NULL)
            continue;
        row->values[i] = pstrdup(argv[i]);
    }

    sqlite_rows_append(res, row);
    // for(i = 0; i<argc; i++) {
    //     elog(NOTICE, "%s = %s", azColName[i], argv[i] ? argv[i] : "NULL");
    // }
    // printf("\n");
   return 0;
}

sqlite3 *
connect2sqlite(char * sqlite_path)
{
    sqlite3 *db = NULL;
    int rc;

    rc = sqlite3_open(sqlite_path, &db);
    if(rc)
    {
        sqlite3_close(db);
        elog(ERROR, "Can't open sqlite database: %s\nError: %s",
                        sqlite_path, sqlite3_errmsg(db));
    }
    return db;
}
