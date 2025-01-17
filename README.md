# pg_sqlite2pg

Open-source tools use in mirgate date from sqlite to pg for Postgres

Not need to consider the table, field type and structure. Automatically analyze the original table structure, automatically convert field types, generate Postgres create table statements, and execute them. And then migrate data.

## Installation
```sh
export PATH=your/path/to/pg_config:$PATH

git clone git@github.com:izhouzhiqiang/pg_sqlite2pg.git
cd pg_sqlite2pg
make && make install
```

## Getting Started

Enable the extension (do this once in each database where you want to use it)

```sql
-- Postgres extension `plpython3u` is required

psql -c "CREATE EXTENSION IF NOT EXISTS plpython3u;"
psql -c "CREATE EXTENSION sqlite2pg;"
```

The functions advise to use list

 Schema |           Name            | Result data type |                   Argument data types                   
--------|---------------------------|------------------|---------------------------------------------------------
 public | generate_create_table     | text             | schema_name text, table_name text, table_columns text[] 
 public | get_sqlite_columns        | text[]           | sqlite_path text, table_name text                       
 public | get_sqlite_tables         | text[]           | sqlite_path text                                        
 public | mirgate_single_table      | text             | sqlite_path text, schema_name text, table_name text     
 public | mirgate_sqlite2pg         | text             | sqlite_path text, schemaname text                       
 public | sqlite2pg_typemap         | text             | sqlite_type text                                        

Mirgate all tables in a database. (Automatically create Schema, table, automatically migrate data)

```sql
select mirgate_sqlite2pg('your/path/to/sqlite.db', 'target_schema');
```

Migrate a single table, (Automatically create Schema, table, automatically migrate data)

```sql
select mirgate_single_table('your/path/to/sqlite.db', 'target_schema', 'source_table_name');
```

Check the tables in SQLite database.

```sql
select get_sqlite_tables('your/path/to/sqlite.db');
```

Check the create table statement in Postgres.

```sql
select generate_create_table('target_schema', 'source_table_name', get_sqlite_columns('your/path/to/sqlite.db', 'source_table_name'));
```

Check the type mapping from SQLite to Postgres.

```sql
select sqlite2pg_typemap('INTEGER');
```

### 1. Record table : sqlite2pg_status

 id | schemaname |      tablename       |  status   | spend_second | mirgated_rows 
----|------------|----------------------|-----------|--------------|---------------
 23 | public     | test_table1          | done      |     0.035714 |          7329
 24 | public     | test_table2          | done      |   287.140082 |        922806
 25 | public     | test_table3          | done      |     3.066727 |         68952
 26 | public     | test_table4          | done      |     1.358614 |         64056
 27 | public     | test_table5          | done      |     0.014504 |           351
 28 | public     | test_table6          | done      |    89.192741 |        503493
 29 | public     | test_table7          | done      |   552.529179 |       1315087
 30 | public     | test_table8          | done      |    43.184426 |        559079

Record the migration status, time spent and migrated rows of each table. This table is stored in `public.sqlite2pg_status`. All tasks share one table.

### 2. Null values handling

Rows in SQLite table may contain NULL values. In the process of migration, special handling is required.

The solution is to use the tuple.__str__() method to convert a tuple into a string.

But in the process of handling NULL values with plpython, it outputs None. Therefore, special processing is required to handle this situation.

So, we use `replace` to handle this situation.

If the value in text type contains "None", it will be converted to NULL together.

This is expected. Mainly for performance considerations. Second, the impact is small.


example:
```sql
insert into test_table1 (id, name, desc) values (123456789,'I Stroe s None' ，None);

replace:
insert into test_table1 (id, name, desc) values (123456789,'I Stroe s Null' ，NULL);
```

### 3. Data Type Mapping

The data types in sqlite and Postgres are not completely the same, so we need to map them.

ref-doc: https://www.sqlite.org/datatype3.html

sqlite类型  | Postgres类型
-----------|------------
\*int\*    | bigint
char       | text
clob       | text
text       | text 
blob       | bytea
real       | real
double     | float8
float      | float8
numeric    | numeric
decimal    | numeric
bool       | boolean
date       | text
time       | text

1. All integer types are converted to bigint (sqlite implements this at the bottom level)
2. All floating-point types are converted to float8
3. All text types are converted to text
4. All binary types are converted to bytea
5. Boolean types are converted to boolean
6. Fixed-point types are converted to numeric
7. Date and time types are converted to text, mainly considering format issues. sqlite's flexible date and time formats can easily cause errors during direct word-for-word conversion in Postgres,

### 4. Schema & Tables
When migrating tables, special cases need to be handled.
- If the schema does not exist, it will be created proactively.
- When migrating tables, if the table already exists, it will be deleted and then recreated.

### 5. Single quoate problem
When the text type contains unescaped single quotes, it will cause SQL execution to fail and result in a failed migration of individual tables.

example:
```sql
-- data in sqlite:
select * from test_table1;
id, name, desc
1, I have a ' in my text, 123456789

-- migrate to postgres:
insert into test_table1 (id, name, desc) values (1, 'I have a ' in my text', 123456789);
```

### 6. Spatial Type

So far, spatial types are not supported. However, theoretically, they can be supported with additional processing:
- Install the spatial plugin in sqlite to support `st_astext` function
- Install postgis plugin in Postgres to support `st_astext` function and IO for Geomtry type

### 7. mirgrate data with rowid & offset
The details of data migration

Since we don't know the number of rows in the table to be migrated, it could be large or small. For performance reasons, segmentation is required during migration.

By default, sqlite tables contain an implicit `rowid` column. During migration, we can use this as a sorting basis for segmented migrations of 1000 rows each time.

If the `WITHOUT ROWID` keyword is used to define a sqlite table, it creates a table without an implicit rowid. In this case, we cannot guarantee that segmented migration will not cause

data inconsistency. In this case, we can only perform a single query on the entire table and insert row by row.


ref-doc : https://www.sqlite.org/rowidtable.html

### 8. Keyword handing
The keywords in sqlite and Postgres do not overlap completely, which can cause some column names in sqlite to fail during table creation migration to Postgres.

To ensure the stability of migration, these column names will be enclosed in double quotes to prevent migration failures.

The keywords can be referenced from the following ref-doc.

The following are the involved keywords:
`all,analyse,analyze,and,any,array,as,asc,asymmetric,authorization,binary,both,case,cast,check,collate,collation,column,concurrently,constraint,create,cross,current_catalog,current_date,current_role,current_schema,current_time,current_timestamp,current_user,default,deferrable,desc,distinct,do,else,end,except,false,fetch,for,foreign,freeze,from,full,grant,group,having,ilike,in,initially,inner,intersect,into,is,isnull,join,lateral,leading,left,like,limit,localtime,localtimestamp,natural,not,notnull,"null",offset,on,only,or,order,outer,overlaps,placing,primary,references,returning,right,select,session_user,similar,some,symmetric,system_user,table,tablesample,then,to,trailing,true,union,unique,user,using,variadic,verbose,when,where,window,with`

example:
```sql
create table test_table1 (
    a int,
    offset int
)

create table test_table1 (
    a bigint,
    "offset" bigint
)
```

ref-doc: 
1. https://www.sqlite.org/lang_keywords.html
2. https://www.postgresql.org/docs/current/sql-keywords-appendix.html
3. https://www.postgresql.org/docs/current/functions-info.html

### 9. Index & Pirmary Key handing
So far, index and primary key migration is not supported.

### 10. Trigger
So far, trigger migration is not supported.

### 11. Foreign Key
So far, foreign key migration is not supported.

### 12. View
So far, view migration is not supported.

### 13. Function
So far, custom function migration is not supported.

### 14. Role & Privilege
So far, role and privilege migration is not supported.

### 15. Constraint
So far, constraint migration is not supported.

### 16. Partitioned table
So far, partitioned table migration is not supported.

### 17. Sqlite3 config
Use absolute path to the sqlite3 database file.

### 18. Long Table Name
Postgres supports table names up to 63 characters. If the length of a sqlite table name exceeds this limit, table name truncation will be truncated automatically.
