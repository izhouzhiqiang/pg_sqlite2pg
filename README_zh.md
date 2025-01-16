# pg_sqlite2pg

Postgres 开源工具，用于将SQLite数据迁移到Postgres

不需要考虑表，字段类型，结构，自动分析原表结构，自动转换字段类型，生成Postgres建表语句，并执行。并进行数据迁移

## 安装
```sh

export PATH=your/path/to/pg_config:$PATH
make && make install

```

## 使用指南

创建拓展（在每个你想使用的数据库中执行一次）

```sql
-- 需要安装 postgres 扩展 `plpython3u`

psql -c "CREATE EXTENSION IF NOT EXISTS plpython3u;"
psql -c "CREATE EXTENSION sqlite2pg;"
```

建议使用的函数列表

 Schema |           Name            | Result data type |                   Argument data types                   
--------|---------------------------|------------------|---------------------------------------------------------
 public | generate_create_table     | text             | schema_name text, table_name text, table_columns text[] 
 public | get_sqlite_columns        | text[]           | sqlite_path text, table_name text                       
 public | get_sqlite_tables         | text[]           | sqlite_path text                                        
 public | mirgate_single_table      | text             | sqlite_path text, schema_name text, table_name text     
 public | mirgate_sqlite2pg         | text             | sqlite_path text, schemaname text                       
 public | sqlite2pg_typemap         | text             | sqlite_type text                                        

迁移整个数据库，（自动创建Schema，table, 自动迁移数据）

```sql
select mirgate_sqlite2pg('your/path/to/sqlite.db', 'target_schema');
```

迁移单个表,（自动创建Schema，table, 自动迁移数据）

```sql
select mirgate_single_table('your/path/to/sqlite.db', 'target_schema', 'source_table_name');
```

查看SQLite数据库中的表
```sql
select get_sqlite_tables('your/path/to/sqlite.db');
```

查看Postgres中执行的建表语句
```sql
select generate_create_table('target_schema', 'source_table_name', get_sqlite_columns('your/path/to/sqlite.db', 'source_table_name'));
```

查看SQLite中的类型在Postgres中的映射
```sql
select sqlite2pg_typemap('INTEGER');
```

### 1. 迁移状态记录表 : sqlite2pg_status

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

记录每张表的迁移状态，花费时间，迁移了多少行数据。此张表存储在`public.sqlite2pg_status`。所有任务共用一张表。

### 2. Null 处理

列中存在NULL值，在迁移过程中，需要特殊处理。

这里的处理方法是使用tuple存储，使用tuple__str__()方法，将tuple转换为字符串。

但在plpython处理NULL的时候，会输出None，所有需要处理

采用了replace，直接将None替换为NULL，作为插入的SQL。

但如果文本类型中的值包含"None", 则会被一起转换为NULL。

这是符合预期的。主要是为了性能考虑。其次，影响比较小。

例如：
```sql
insert into test_table1 (id, name, desc) values (123456789,'I Stroe s None' ，None);

replace:
insert into test_table1 (id, name, desc) values (123456789,'I Stroe s Null' ，NULL);
```

### 3. 数据类型映射

sqlite中和Postgres中的数据类型不完全相同，需要映射。

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
float      | float8SQLite
当迁移表的时候，需要处理一些特殊情况。
- 当schema不存在的时候，会主动创建schema
- 当迁移表的时候，如果表已经存在，会将表删除，然后再创建表。

### 5. 单引号问题
在文本类型中包含未转义的单引号，会导致SQL执行失败，从而导致单表执行失败。

example:
```sql
-- data in sqlite:
select * from test_table1;
id, name, desc
1, I have a ' in my text, 123456789

-- migrate to postgres:
insert into test_table1 (id, name, desc) values (1, 'I have a ' in my text', 123456789);
```

### 6. 空间几何类型
目前不支持spatial类型，但理论上可以支持，需要额外的处理。

- sqlite中安装spatial插件，支持st_astext函数
- Postgres中安装postgis插件，支持st_astext函数，和Geomtry类型的IO

### 7. mirgrate data with rowid & offset
数据迁移的分段细节

因为不知道我们需要迁移的表的行数，可能很大，也可能很小，所以出于性能考虑，需要分段迁移。

默认情况下，sqlite表中包含一个隐式的rowid列，在迁移过程中，我们可以以此列为排序依据进行每次1000行的分段迁移。

如果在定义sqlite表的时候，使用了`WITHOUT ROWID`关键字，则会创建一个不带rowid的表。这种情况下，我们无法保证使用分段迁移，会不会导致数据不一致。因此，这种情况下，我们只能对整个表进行一次性的查询，然后逐行插入。

ref-doc : https://www.sqlite.org/rowidtable.html

### 8. 关键字处理
sqlite中关键字和Postgres关键字不完全的重叠， 由此会导致在sqlite中的一些列名在迁移到Postgres中建表的时候，会导致执行失败。

为了保证迁移的稳定性，在遇到这些列名的时候，会将列名加上双引号，来保证迁移不会失败

这些关键字如何得出的可以参考下列 ref-doc

涉及的关键字如下:
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
目前暂时不支持索引和主键的迁移。

### 10. Trigger
目前暂时不支持触发器的迁移。

### 11. Foreign Key
目前暂时不支持外键的迁移。

### 12. View
目前暂时不支持视图的迁移。

### 13. Function
目前暂时不支持自定义函数的迁移。

### 14. Role & Privilege
目前暂时不支持角色和权限的迁移。

### 15. Constraint
目前暂时不支持约束的迁移。

### 16. Partitioned table
sqlite中不存在分区表，目前暂时不支持分区表的迁移。

### 17. Sqlite3 config
使用SQLite绝对路径迁移数据库
