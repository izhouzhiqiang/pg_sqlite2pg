-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION sqlite2pg" to load this file. \quit

-- reference:
-- https://www.sqlite.org/datatype3.html Data Type Map
-- https://www.sqlite.org/rowidtable.html rowid column


-- get_sqlite_tables
-- get_sqlite_columns
-- get_sqlite_index
-- generate_create_table
-- generate_create_index


CREATE FUNCTION pymax (a integer, b integer)
RETURNS integer
AS $$
  if a > b:
    return a
  return b
$$ LANGUAGE plpython3u;

CREATE FUNCTION get_keyword_list()
RETURNS text[]
AS $$
  res = plpy.execute("select pg_get_keywords()")
  ret = []
  for x in res:
    # {'pg_get_keywords': { 'word': 'absent', 'catcode': 'U', 'barelabel': True, 'catdesc': 'unreserved', 'baredesc': 'can be bare label' }}
    info = dict(x)['pg_get_keywords']
    if info['catcode'] in ('R', 'T'):
      # plpy.notice(info['word'])
      ret.append(info['word'])
    # plpy.notice(dict(x)['pg_get_keywords'])

  return ret
$$ LANGUAGE plpython3u;

CREATE FUNCTION get_sqlite_tables(sqlite_path text)
RETURNS text[]
AS $$
  import sqlite3
  import os

  if not os.path.exists(sqlite_path):
    plpy.error("SQLite file not found: %s" % sqlite_path)
  if not os.path.isfile(sqlite_path):
    plpy.error("%s is not a file" % sqlite_path)

  conn = sqlite3.connect(sqlite_path)
  cur = conn.cursor()
  cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
  res = [x[0] for x in cur.fetchall()]
  cur.close()
  conn.close()

  return res
$$ LANGUAGE plpython3u;

CREATE FUNCTION get_sqlite_columns(sqlite_path text, table_name text)
RETURNS text[]
AS $$
  import sqlite3
  import os

  if not os.path.exists(sqlite_path):
    plpy.error("SQLite file not found: %s" % sqlite_path)
  if not os.path.isfile(sqlite_path):
    plpy.error("%s is not a file" % sqlite_path)

  conn = sqlite3.connect(sqlite_path)
  cur = conn.cursor()
  cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='%s'" % (table_name))
  if cur.fetchone() is None:
    plpy.error("Table not found: %s" % table_name)
  cur.execute("PRAGMA table_info(%s)" % (table_name))
  res = []
  for x in cur.fetchall():
    res.append(x[1])
    res.append(x[2].replace('"', '').split(' ')[0].lower())
  cur.close()
  conn.close()

  return res
$$ LANGUAGE plpython3u;

CREATE FUNCTION sqlite_rowid_exists(sqlite_path text, table_name text)
RETURNS boolean
AS $$
  import sqlite3
  import os

  if not os.path.exists(sqlite_path):
    plpy.error("SQLite file not found: %s" % sqlite_path)
  if not os.path.isfile(sqlite_path):
    plpy.error("%s is not a file" % sqlite_path)

  conn = sqlite3.connect(sqlite_path)
  cur = conn.cursor()
  cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='%s'" % (table_name))
  if cur.fetchone() is None:
    plpy.error("Table not found: %s" % table_name)
  res = cur.execute("SELECT lower(sql) FROM sqlite_master WHERE type='table' AND name='%s'" % (table_name))
  res = res.fetchone()[0]
  if "without" in res and "rowid" in res:
    return False
  # plpy.notice(res)

  return True
$$ LANGUAGE plpython3u;
-- CREATE FUNCTION get_sqlite_index(sqlite_path text, table_name text)
-- RETURNS text[]
-- AS $$
--   import sqlite3
--   import os

--   if not os.path.exists(sqlite_path):
--     plpy.error("SQLite file not found: %s" % sqlite_path)
--   if not os.path.isfile(sqlite_path):
--     plpy.error("%s is not a file" % sqlite_path)

--   conn = sqlite3.connect(sqlite_path)
--   cur = conn.cursor()
--   cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='%s'" % (table_name))
--   if cur.fetchone() is None:
--     plpy.error("Table not found: %s" % table_name)
--   cur.execute("PRAGMA index_list(%s)" % (table_name))
  
-- $$ LANGUAGE plpython3u;

CREATE FUNCTION generate_create_table(
  schema_name text,
  table_name text,
  table_columns text[])
RETURNS text
AS $$
  import re

  if len(table_columns) % 2 != 0:
    plpy.error("table_columns must have an even number of elements")

  schema_list = plpy.execute("select nspname from pg_namespace where nspname = '%s'" % (schema_name))
  if len(schema_list) == 0:
    plpy.warning("Schema %s not found" % schema_name)
  # plpy.notice(schema_list)

  keywords = plpy.execute("SELECT get_keyword_list() as colname")[0]["colname"]
  # plpy.notice(keywords)
  sql_str = "DROP TABLE IF EXISTS %s.%s;CREATE TABLE %s.%s " % (schema_name, table_name, schema_name, table_name)
  sql_str += "("
  comma = ''
  for i in range(0, len(table_columns), 2):
    col_name = table_columns[i]
    col_type = table_columns[i+1]
    if col_name in keywords:
      col_name = '"%s"' % col_name
      plpy.warning("Column name %s is a keyword, using double quotes" % col_name)
    sql_str += "%s\n%s %s" % (comma, col_name, col_type)
    comma = ','
  sql_str += '\n)'

  return sql_str
$$ LANGUAGE plpython3u;

CREATE FUNCTION sqlite2pg_typemap(sqlite_type text)
RETURNS text
AS $$
  lower_type = sqlite_type.lower()
  map = {
    'int': 'bigint',
    'char': 'text',
    'clob': 'text',
    'text': 'text',
    'blob': 'bytea',
    'real': 'float8',
    'double': 'float8',
    'float': 'float8',
    'numeric': 'decimal',
    'decimal': 'numeric',
    'bool': 'boolean',
    'date': 'text',
    'time': 'text',
  }
  for k, v in map.items():
    if k in lower_type:
      return v

  return 'text'
$$ LANGUAGE plpython3u;


CREATE FUNCTION mirgate_single_table(
  sqlite_path text,
  schema_name text,
  table_name text)
RETURNS text
AS $$
  import sqlite3
  import os
  import time

  if not os.path.exists(sqlite_path):
    plpy.error("SQLite file not found: %s" % sqlite_path)
  if not os.path.isfile(sqlite_path):
    plpy.error("%s is not a file" % sqlite_path)

  plpy.execute("select __create_sqlite2pg_status()")
  status_id = plpy.execute("select __insert_sqlite2pg_status('%s', '%s') as res" % (schema_name, table_name))[0]["res"]
  plpy.notice("sqlite2pg_status id: %s" % status_id)

  begin_time = time.time()
  keywords = plpy.execute("SELECT get_keyword_list() as colname")[0]["colname"]

  conn = sqlite3.connect(sqlite_path)
  cur = conn.cursor()
  cur.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='%s'" % (table_name))
  if cur.fetchone() is None:
    plpy.error("Table not found: %s" % table_name)
  
  have_rowid = plpy.execute("select sqlite_rowid_exists('%s', '%s')" % (sqlite_path, table_name))[0]["sqlite_rowid_exists"]
  # plpy.notice("Have rowid: %s" % have_rowid)
  
  cols = plpy.execute("select get_sqlite_columns('%s', '%s')" % (sqlite_path, table_name))[0]["get_sqlite_columns"]
  if len(cols) % 2 != 0:
    plpy.error("Columns must have an even number of elements")
  
  rownames = ""
  for i in range(0, len(cols), 2):
    cols[i+1] = plpy.execute("select sqlite2pg_typemap('%s')" % (cols[i+1]))[0]["sqlite2pg_typemap"]
    rownames += ('' if rownames == "" else ', ') + (cols[i] if cols[i] not in keywords else '"%s"' % cols[i])

  rownames_list = '(' + rownames + ')'
  # plpy.notice("Columns: %s" % rownames)
  rows_define = '{' + ','.join(cols) + '}'
  create_table_sql = plpy.execute("select generate_create_table('%s', '%s', '%s'::text[])" % (schema_name, table_name, rows_define))[0]["generate_create_table"]
  # plpy.notice("Create table SQL: %s" % create_table_sql)

  plpy.execute(create_table_sql)

  inserted_header_str = "INSERT INTO %s.%s %s VALUES" % (schema_name, table_name, rownames_list)
  inserted_value_str = ""
  total_num = 0
  if not have_rowid:
    total_num = 0
    all_rows = cur.execute("SELECT %s FROM %s" % (rownames, table_name))
    for row in all_rows.fetchall():
      fmt_row = row.__str__().replace("None", "NULL")
      inserted_value_str += ('' if inserted_value_str == "" else ', ') + fmt_row
      run_sql = inserted_header_str + fmt_row + ";"
      # plpy.notice("Inserted values: %s" % inserted_value_str)
      plpy.execute(run_sql)
      total_num += 1
      # if total_num % 10000 == 0:
      #  plpy.execute("select __update_sqlite2pg_status('mirgated_rows=%d', 'id=%d')" % (total_num, status_id))
      #  plpy.commit()
    end_time = time.time()
    plpy.execute("select __update_sqlite2pg_status('mirgated_rows=%d,status=''done'',spend_second=%f ', 'id=%d')" % (total_num, end_time - begin_time, status_id))
  else:
    once_limit = 1000
    offset = 0
    total_num = 0
    while True:
      inserted_value_str = ""
      all_rows = cur.execute("SELECT %s FROM %s order by rowid limit %d offset %d" % (rownames, table_name, once_limit, offset)).fetchall()
      offset += once_limit
      total_num += len(all_rows)
      if len(all_rows) == 0:
        break
      for row in all_rows:
        fmt_row = row.__str__().replace("None", "NULL")
        inserted_value_str += ('' if inserted_value_str == "" else ', ') + fmt_row
      run_sql = inserted_header_str + fmt_row + ";"
      # plpy.notice("Inserted values: %s" % inserted_value_str)
      plpy.execute(run_sql)
      # if total_num % 10000 == 0:
      #  plpy.execute("select __update_sqlite2pg_status('mirgated_rows=%d', 'id=%d')" % (total_num, status_id))
      #  plpy.commit()
    end_time = time.time()
    plpy.execute("select __update_sqlite2pg_status('mirgated_rows=%d,status=''done'',spend_second=%f', 'id=%d')" % (total_num, end_time - begin_time, status_id))

  return 'success'
$$ LANGUAGE plpython3u;

CREATE FUNCTION __create_sqlite2pg_status()
RETURNS text
AS $$
  query = "select count(*) from pg_tables where schemaname='public' and tablename='sqlite2pg_status'"
  sql_create = "CREATE TABLE public.sqlite2pg_status (id serial primary key, schemaname text, tablename text,status text, spend_second float8, mirgated_rows int);"
  if plpy.execute(query)[0]["count"] == 0:
    plpy.execute(sql_create)

  return "success" 
$$ LANGUAGE plpython3u;

CREATE FUNCTION __insert_sqlite2pg_status(schemaname text, tablename text)
RETURNS int
AS $$
  plpy.execute("insert into sqlite2pg_status (schemaname, tablename, status, mirgated_rows) values ('%s', '%s', '%s', 0)" % (schemaname, tablename, 'migrating'))
  res = plpy.execute("select id from sqlite2pg_status where schemaname='%s' and tablename='%s' order by id desc limit 1" % (schemaname, tablename))
  if len(res) == 0:
    plpy.error("Failed to insert sqlite2pg_status")
  return res[0]["id"]
$$ LANGUAGE plpython3u;

CREATE FUNCTION __update_sqlite2pg_status(set_str text, where_str text)
RETURNS text
AS $$
  plpy.execute("update sqlite2pg_status set %s where %s" % (set_str, where_str))

  return "success"
$$ LANGUAGE plpython3u;

CREATE FUNCTION mirgate_sqlite2pg(sqlite_path text,schemaname text)
RETURNS text
AS $$
  import os
  import sqlite3
  import time

  if not os.path.exists(sqlite_path):
    plpy.error("SQLite file not found: %s" % sqlite_path)
  if not os.path.isfile(sqlite_path):
    plpy.error("SQLite path is not a file: %s" % sqlite_path)
  if len(plpy.execute("select nspname from pg_namespace where nspname='%s'" % schemaname)) == 0:
    plpy.notice("Schema ""%s"" not found, creating..." % schemaname)
    plpy.execute("CREATE SCHEMA %s" % schemaname)

  conn = sqlite3.connect(sqlite_path)
  cur = conn.cursor()
  all_tables = cur.execute("select name from sqlite_master where type='table'").fetchall()
  table_names = [x[0] for x in all_tables]
  # plpy.notice("Found tables in SQLite file :%s" % table_names)

  for table_name in table_names:
    try:
      plpy.execute("select mirgate_single_table('%s', '%s', '%s')" % (sqlite_path, schemaname, table_name))
    except Exception as e:
      plpy.notice("Failed to migrate table "%s": %s" % (table_name, e))
  return 'success'
$$ LANGUAGE plpython3u;


-- CREATE FUNCTION test_sqlite2pg_typemap(sqlite_type text)
-- RETURNS text
-- AS $$
--   return sqlite2pg_typemap(sqlite_type)
-- $$ LANGUAGE plpython3u;
