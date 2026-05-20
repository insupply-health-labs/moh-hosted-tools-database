# MOH Shared PostgreSQL Database Stack

This project folder is responsible only for the shared database infrastructure used by MOH-hosted applications.

It provides:

- A persistent PostgreSQL container
- A pgAdmin container for database administration
- A scheduled PostgreSQL backup container
- A host-mounted backup directory
- A shared Docker network that application stacks can join
- Separate databases and users for each app

## Recommended architecture

Use one shared PostgreSQL server/container, but give every app its own database and user. 

```text
moh_postgres
├── moh_forecasting_tool_db       -> moh_forecasting_tool_user
├── smart_tool_db                 -> smart_tool_user
├── indicator_tracking_db         -> indicator_tracking_user
└── fp_mnch_commodities_db        -> fp_mnch_commodities_user
```

This is usually better than putting all apps into one database with different schemas because it gives cleaner isolation, easier backups, easier restores, simpler migrations, and safer permissions.

## Folder structure

```text
moh-shared-postgres/
├── docker-compose.yml
├── .env
├── README.md
├── database/
│   ├── init/
│   │   └── 01-create-app-databases.sh
│   └── backups/
└── scripts/
    └── restore-database-example.sh
```

## First-time setup

Create the external Docker network:

```bash
docker network create moh_backend_network
```

Create a `.env` file and ensure all values in the `.env.example` are set.

Make sure the init script is executable:

```bash
chmod +x database/init/01-create-app-databases.sh
```

Start the database stack:

```bash
docker compose --env-file ./.env up --build
```

Check status:

```bash
docker compose ps
```

View logs:

```bash
docker compose logs -f moh_postgres
```

## Important persistence note

PostgreSQL data is stored in a named Docker volume:

```yaml
moh_postgres_data
```

This means database data survives:

```bash
docker compose down
docker compose up -d --build
```

Do not run this unless you intentionally want to delete database data:

```bash
docker compose down -v
```

The `-v` flag deletes named volumes, including the PostgreSQL data volume.

## Backups

Backups are stored on the host at:

```text
./database/backups
```

The default backup schedule is daily at `02:17` Africa/Nairobi time:

```env
BACKUP_SCHEDULE=17 2 * * *
```

Retention defaults:

```env
BACKUP_KEEP_DAYS=7
BACKUP_KEEP_WEEKS=4
BACKUP_KEEP_MONTHS=6
```

You should periodically copy the backup folder to an offsite location or another secure MOH-managed storage location.

## Connecting from app containers

Any application backend running in Docker should join the same external network:

```yaml
networks:
  moh_backend_network:
    external: true
```

Example backend service:

```yaml
services:
  smart_backend:
    image: your-smart-backend-image
    env_file:
      - ./.env
    networks:
      - moh_backend_network

networks:
  moh_backend_network:
    external: true
```

Inside the app container, connect using the Docker service/container name:

```env
DATABASE_URL=postgresql+asyncpg://smart_tool_user:SMART_PASSWORD@moh_postgres:5432/smart_tool_db
```

Do not use `localhost` from inside an app container. Inside a container, `localhost` means the app container itself, not the Postgres container.

## Connecting from outside Docker

If an app or admin tool is outside the Docker network, it can connect using:

```text
<server-ip-or-domain>:5678
```

Example:

```env
DATABASE_URL=postgresql+asyncpg://smart_tool_user:SMART_PASSWORD@<server-ip-or-domain>:5678/smart_tool_db
```

## pgAdmin

pgAdmin is exposed on:

```text
http://<server-ip-or-domain>:55050
```

The login credentials are configured in `.env`:

```env
PGADMIN_DEFAULT_EMAIL=admin@example.org
PGADMIN_DEFAULT_PASSWORD=CHANGE_ME_PGADMIN_PASSWORD
```

## Adding another application database

1. Add new variables to `.env`:

```env
NEW_APP_DB=new_app_db
NEW_APP_USER=new_app_user
NEW_APP_PASSWORD=CHANGE_ME_NEW_APP_PASSWORD
```

2. Add the database name to:

```env
BACKUP_DATABASES=moh_forecasting_tool_db,smart_tool_db,indicator_tracking_db,fp_mnch_commodities_db,new_app_db
```

3. Add another line in `database/init/01-create-app-databases.sh`:

```bash
create_database_and_user "${NEW_APP_DB}" "${NEW_APP_USER}" "${NEW_APP_PASSWORD}"
```

If the PostgreSQL volume already exists, the init script will not automatically rerun. In that case, create the new user/database manually using `docker exec` or pgAdmin.

Example manual command:

```bash
docker exec -it moh_postgres psql -U moh_postgres_admin -d moh_admin_db
```

Then run SQL such as:

```sql
CREATE USER new_app_user WITH PASSWORD 'strong_password';
CREATE DATABASE new_app_db OWNER new_app_user;
GRANT ALL PRIVILEGES ON DATABASE new_app_db TO new_app_user;
```

## Restore example

A starter restore script is included at:

```text
scripts/restore-database-example.sh
```

Review and adapt it before using it in production.

## Production recommendations

- Use strong, unique passwords for every app database user.
- Do not reuse the superuser credentials in application backends.
- Restrict the exposed PostgreSQL port to approved server IPs only.
- Prefer Docker internal networking when apps are hosted on the same server.
- Test backup restoration before relying on backups.
- Copy backups off the server regularly.
- Avoid `docker compose down -v` unless you are intentionally resetting the database.
