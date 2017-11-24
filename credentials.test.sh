#
# Credentials for test vitess setup.
#
# - the credentials do not have very secure passwords and probably should be fixed.
#

# easier to read this way (I think)
_DBA_FLAGS="-db-config-dba-uname vt_dba -db-config-dba-pass xxxxxxxxxxx -db-config-dba-charset utf8mb4"
_ALL_PRIVS_FLAGS="-db-config-allprivs-uname vt_allprivs -db-config-allprivs-pass bbbbbbbbbbbbbbbb -db-config-allprivs-charset utf8mb4"
_APP_FLAGS="-db-config-app-uname vt_app -db-config-app-pass ccccccccccc -db-config-app-charset utf8mb4"
_REPL_FLAGS="-db-config-repl-uname vt_repl -db-config-repl-pass dddddddddd -db-config-repl-charset utf8mb4"
_FILTERED_FLAGS="-db-config-filtered-uname vt_filtered -db-config-filtered-pass eeeeeeeeee -db-config-filtered-charset utf8mb4"

DBCONFIG_DBA_FLAGS=${_DBA_FLAGS}
DBCONFIG_FLAGS="${_DBA_FLAGS} ${_ALL_PRIVS_FLAGS} ${_APP_FLAGS} ${_REPL_FLAGS} ${_FILTERED_FLAGS}"
INIT_DB_SQL_FILE=/path/to/init_db.sql
