-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION sqlite2pg" to load this file. \quit

CREATE OR REPLACE FUNCTION test_c()
RETURNS integer
AS 'MODULE_PATHNAME', 'test_c'
LANGUAGE C IMMUTABLE PARALLEL SAFE;

CREATE OR REPLACE FUNCTION connect_sqlite()
RETURNS void
AS 'MODULE_PATHNAME', 'connect_sqlite'
LANGUAGE C;

CREATE OR REPLACE FUNCTION is_legal_colname(kw text)
RETURNS boolean
AS 'MODULE_PATHNAME', 'is_legal_colname'
LANGUAGE C;

CREATE OR REPLACE FUNCTION get_sqlite_tables_c(sqlite_path text)
RETURNS text[]
AS 'MODULE_PATHNAME', 'get_sqlite_tables_c'
LANGUAGE C;
