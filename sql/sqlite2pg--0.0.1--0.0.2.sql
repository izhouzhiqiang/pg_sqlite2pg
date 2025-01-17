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

CREATE OR REPLACE FUNCTION is_keyword(kw text)
RETURNS boolean
AS 'MODULE_PATHNAME', 'is_keyword'
LANGUAGE C;
