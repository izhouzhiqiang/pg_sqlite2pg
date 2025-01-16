# pg_sqlite2pg

Open-source tools use in mirgate date from sqlite to pg for Postgres

## Installation
```sh
# postgres extension `plpython3u` is required

export PATH=your/path/to/pg_config:$PATH
make && make install

```

## Getting Started

Enable the extension (do this once in each database where you want to use it)

```tsql
psql -c "CREATE EXTENSION IF NOT EXISTS plpython3u;"
psql -c "CREATE EXTENSION sqlite2pg;"
```

Create a vector column with 3 dimensions

```sql
CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3));
```

Insert vectors

```sql
INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
```

Get the nearest neighbors by L2 distance

```sql
SELECT * FROM items ORDER BY embedding <-> '[3,1,2]' LIMIT 5;
```

Also supports inner product (`<#>`), cosine distance (`<=>`), and L1 distance (`<+>`, added in 0.7.0)

Note: `<#>` returns the negative inner product since Postgres only supports `ASC` order index scans on operators

## Storing

Create a new table with a vector column

```sql
CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3));
```

Or add a vector column to an existing table

```sql
ALTER TABLE items ADD COLUMN embedding vector(3);
```

Also supports [half-precision](#half-precision-vectors), [binary](#binary-vectors), and [sparse](#sparse-vectors) vectors

Insert vectors

```sql
INSERT INTO items (embedding) VALUES ('[1,2,3]'), ('[4,5,6]');
```

Or load vectors in bulk using `COPY` ([example](https://github.com/pgvector/pgvector-python/blob/master/examples/loading/example.py))

```sql
COPY items (embedding) FROM STDIN WITH (FORMAT BINARY);
```

Upsert vectors

```sql
INSERT INTO items (id, embedding) VALUES (1, '[1,2,3]'), (2, '[4,5,6]')
    ON CONFLICT (id) DO UPDATE SET embedding = EXCLUDED.embedding;
```

Update vectors

```sql
UPDATE items SET embedding = '[1,2,3]' WHERE id = 1;
```

Delete vectors

```sql
DELETE FROM items WHERE id = 1;
```

## Querying

Get the nearest neighbors to a vector

```sql
SELECT * FROM items ORDER BY embedding <-> '[3,1,2]' LIMIT 5;
```

Supported distance functions are:

- `<->` - L2 distance
- `<#>` - (negative) inner product
- `<=>` - cosine distance
- `<+>` - L1 distance (added in 0.7.0)
- `<~>` - Hamming distance (binary vectors, added in 0.7.0)
- `<%>` - Jaccard distance (binary vectors, added in 0.7.0)

Get the nearest neighbors to a row

```sql
SELECT * FROM items WHERE id != 1 ORDER BY embedding <-> (SELECT embedding FROM items WHERE id = 1) LIMIT 5;
```

Get rows within a certain distance

```sql
SELECT * FROM items WHERE embedding <-> '[3,1,2]' < 5;
```

Note: Combine with `ORDER BY` and `LIMIT` to use an index

## some detailes & problems need to be noted

firstly, many questions belowed can be solved, but efficiency is more important. So, some details that appear at a low rate, but may cause performance or I can not get a better way to achieve it in a effctive way. these issues are summarized here.

### 1. Record table : sqlite2pg_status

### 2. Null values handling

### 3. Data Type Mapping

### 4. Schema

### 5. Single quoate problem

### 6. Spatial Type

### 7. mirgrate data with rowid & offset

### 8. Keyword handing

### 9. Index & Pirmary Key handing

### 10. Trigger

### 11. Foreign Key

### 12. View

### 13. Function

### 14. Role & Privilege

### 15. Constraint

### 16. Partitioned table

### 17. Sqlite3 config
