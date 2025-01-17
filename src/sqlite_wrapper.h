/*
 * src/sqlite_wrapper.h
 */
#ifndef SQLITE_WRAPPER_H
#define SQLITE_WRAPPER_H

# include <stdio.h>
# include <stdlib.h>

# include "postgres.h"
# include "fmgr.h"
# include "utils/elog.h"

# include "sqlite_driver/sqlite3.h"

typedef struct sqlite_row {
    int                 length;     /* number of rows in the result set */
    char                **values;   /* array of values */
    struct sqlite_row   *next;      /* next result set */
} sqlite_row;

typedef struct sqlite_query_result {
    int         n_rows;           /* number of rows in the result set */
    int         n_columns;      /* number of columns in the result set */
    char        **column_names; /* array of column names */
    sqlite_row *head;          /* first result set */
    sqlite_row *end;           /* current result set */
} sqlite_query_result;

int sqlite_rows_callback(void *result, int argc, char **argv, char **azColName);
sqlite3 *connect2sqlite(char * sqlite_path);
sqlite_query_result *init_sqlite_query_result(void);
void sqlite_rows_append(sqlite_query_result *result, sqlite_row *new_row);
void free_sqlite_query_result(sqlite_query_result *result);

#endif /* !SQLITE_WRAPPER_H */
