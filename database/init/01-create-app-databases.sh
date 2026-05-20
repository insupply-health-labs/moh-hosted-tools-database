#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Create application databases and users
#
# This script runs automatically only when the PostgreSQL data volume is empty.
# It creates one database and one user per application.
# ==============================================================================
 
create_database_and_user() {
  local database_name="$1"
  local database_user="$2"
  local database_password="$3"

  echo "Creating user and database for: ${database_name}"

  psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOSQL
    DO
    \$\$
    BEGIN
      IF NOT EXISTS (
        SELECT FROM pg_catalog.pg_roles
        WHERE rolname = '${database_user}'
      ) THEN
        CREATE ROLE ${database_user}
        WITH LOGIN PASSWORD '${database_password}';
      END IF;
    END
    \$\$;

    SELECT 'CREATE DATABASE ${database_name} OWNER ${database_user}'
    WHERE NOT EXISTS (
      SELECT FROM pg_database WHERE datname = '${database_name}'
    )\gexec

    GRANT ALL PRIVILEGES ON DATABASE ${database_name} TO ${database_user};
EOSQL

  # Ensure the app user owns and can manage objects in the public schema.
  psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${database_name}" <<-EOSQL
    ALTER SCHEMA public OWNER TO ${database_user};
    GRANT ALL ON SCHEMA public TO ${database_user};
    GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO ${database_user};
    GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO ${database_user};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO ${database_user};
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO ${database_user};
EOSQL

  echo "Finished setup for: ${database_name}"
}

create_database_and_user "${MOH_FORECASTING_DB}" "${MOH_FORECASTING_USER}" "${MOH_FORECASTING_PASSWORD}"
create_database_and_user "${SMART_DB}" "${SMART_USER}" "${SMART_PASSWORD}"
create_database_and_user "${INDICATOR_TRACKING_DB}" "${INDICATOR_TRACKING_USER}" "${INDICATOR_TRACKING_PASSWORD}"
create_database_and_user "${FP_MNCH_DB}" "${FP_MNCH_USER}" "${FP_MNCH_PASSWORD}"

echo "All application databases and users have been initialized."
