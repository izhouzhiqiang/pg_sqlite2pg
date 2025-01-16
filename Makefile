EXTENSION = sqlite2pg
DATA = sql/sqlite2pg--0.0.1.sql

# mytest:
# 	make install && sh ./run_test.sh

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)