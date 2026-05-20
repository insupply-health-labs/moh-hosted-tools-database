#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Example PostgreSQL restore script
#
# Usage:
#   ./scripts/restore-database-example.sh smart_tool_db ./database/backups/example.sql.gz
#
# Important:
#   - Review before using in production.
#   - Restoring into an existing database can overwrite or conflict with data.
#   - Test restore procedures in a staging environment first.
# ==============================================================================

DATABASE_NAME="${1:-}"
BACKUP_FILE="${2:-}"

if [[ -z "${DATABASE_NAME}" || -z "${BACKUP_FILE}" ]]; then
  echo "Usage: $0 <database_name> <backup_file.sql.gz>"
  exit 1
fi

if [[ ! -f "${BACKUP_FILE}" ]]; then
  echo "Backup file not found: ${BACKUP_FILE}"
  exit 1
fi

echo "Restoring ${BACKUP_FILE} into database ${DATABASE_NAME}"

gunzip -c "${BACKUP_FILE}" | docker exec -i moh_postgres psql \
  -U "${POSTGRES_SUPERUSER:-postgres}" \
  -d "${DATABASE_NAME}"

echo "Restore complete."
