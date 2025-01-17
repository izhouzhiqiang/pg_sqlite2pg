MODULE_big = sqlite2pg
EXTENSION = sqlite2pg
DATA = sql/sqlite2pg--0.0.1.sql	\
	   sql/sqlite2pg--0.0.1--0.0.2.sql

OBJS = \
	$(WIN32RES)	\
	src/sqlite2pg.o	\
	src/sqlite_wrapper.o	\
	src/sqlite_driver/sqlite3.o

PG_CFLAGS = -std=c99 -ggdb -O2
# REGRESS = \

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

mytest:
	make && make install && sh ./run_test.sh