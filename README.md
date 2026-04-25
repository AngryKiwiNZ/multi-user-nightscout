# multi-user-nightscout

Run many upstream Nightscout instances with:

- one shared MongoDB container
- one Nginx reverse proxy
- one database per site
- one Nightscout container per site
- two Docker networks instead of dozens

This repo is intentionally a Docker orchestration layer around the official Nightscout project. You can either:

- pull the published upstream image from Docker Hub
- or clone the official Nightscout repo locally and build from that checkout

That gives you a clean way to host many sites without maintaining your own app fork.

## Architecture

```text
Internet
  |
  v
nginx
  |
  +--> nightscout-jay ------+
  +--> nightscout-user2 ----+--> mongo:27017
  +--> nightscout-user3 ----+

proxy-net: nginx + all Nightscout containers
mongo-net: mongo + all Nightscout containers
```

Each site gets its own Mongo database, for example:

- `ns_jay`
- `ns_user2`
- `ns_user3`

## Repo layout

- [compose.yaml](/Users/jay/Documents/multi-user-nightscout/compose.yaml)
- [config/sites.csv.example](/Users/jay/Documents/multi-user-nightscout/config/sites.csv.example)
- [sites/jay.env.example](/Users/jay/Documents/multi-user-nightscout/sites/jay.env.example)
- [scripts/render-sites.sh](/Users/jay/Documents/multi-user-nightscout/scripts/render-sites.sh)
- [scripts/create-new-site.sh](/Users/jay/Documents/multi-user-nightscout/scripts/create-new-site.sh)
- [scripts/import-existing-site.sh](/Users/jay/Documents/multi-user-nightscout/scripts/import-existing-site.sh)
- [scripts/pull-nightscout-upstream.sh](/Users/jay/Documents/multi-user-nightscout/scripts/pull-nightscout-upstream.sh)
- [scripts/backup-all.sh](/Users/jay/Documents/multi-user-nightscout/scripts/backup-all.sh)
- [scripts/migrate-site.sh](/Users/jay/Documents/multi-user-nightscout/scripts/migrate-site.sh)

## Easy version

Think of this repo as the control panel around Nightscout.

- Nightscout itself still comes from the official project.
- This repo just manages shared Mongo, Nginx, and one Nightscout container per site.
- A brand new site starts directly on the shared Mongo server.
- An old site can be copied into the shared Mongo server and switched over later.

## Choose how to run Nightscout

### Option 1: Use the official published Docker image

This is the default and simplest option.

```dotenv
NIGHTSCOUT_SOURCE_MODE=image
NIGHTSCOUT_IMAGE=nightscout/cgm-remote-monitor:latest
```

### Option 2: Clone the official repo and build from upstream source

If you want a local checkout of the official repo as well:

```bash
./scripts/pull-nightscout-upstream.sh
```

Then set:

```dotenv
NIGHTSCOUT_SOURCE_MODE=build
NIGHTSCOUT_UPSTREAM_DIR=./upstream/cgm-remote-monitor
NIGHTSCOUT_IMAGE=multi-user-nightscout:upstream
```

When `NIGHTSCOUT_SOURCE_MODE=build`, Docker Compose builds the Nightscout app from the cloned official repo instead of pulling only the published image.

## Shared setup

1. Copy the inventory and site env examples:

```bash
cp config/sites.csv.example config/sites.csv
cp sites/jay.env.example sites/jay.env
```

2. Optionally choose image mode or build-from-upstream mode in `.env`.

3. Render the generated compose and Nginx config:

```bash
./scripts/render-sites.sh
```

4. Start everything:

```bash
docker compose -f compose.yaml -f generated/compose.sites.yaml up -d
```

## Brand new site

For a brand new site, you do not create a separate Mongo first.

Just run:

```bash
./scripts/create-new-site.sh jay jay.example.nz
```

That will:

- add the site to `config/sites.csv`
- create `sites/jay.env` from the example if needed
- assign the site its own database, like `ns_jay`
- regenerate the compose and Nginx files

Then:

```bash
vi sites/jay.env
docker compose -f compose.yaml -f generated/compose.sites.yaml up -d
```

When the site starts, Nightscout will create and use its own database inside the shared Mongo server.

## Existing site migration

For an existing standalone Nightscout site that already has its own Mongo:

```bash
./scripts/import-existing-site.sh jay jay.example.nz mongo-jay nightscout
```

That will:

- add the site to `config/sites.csv`
- create `sites/jay.env` if needed
- regenerate the compose and Nginx files
- copy data from the old Mongo container into the shared Mongo server

Then you start the shared-stack version of that site:

```bash
vi sites/jay.env
docker compose -f compose.yaml -f generated/compose.sites.yaml up -d
```

After testing, you can stop the old Mongo container. You do not need to delete it immediately.

## Site inventory format

`config/sites.csv` is a simple comma-separated file:

```csv
slug,domain,db_name,env_file
jay,jay.example.nz,ns_jay,sites/jay.env
```

Rules:

- `slug` becomes part of the container name
- `domain` is used in the generated Nginx vhost
- `db_name` is the Mongo database for that site
- `env_file` points to that site's Nightscout environment file

## Shared settings

Set these as shell env vars before running compose, or place them in a local `.env` file:

```dotenv
COMPOSE_PROJECT_NAME=multi-user-nightscout
TZ=Pacific/Auckland
NIGHTSCOUT_IMAGE=nightscout/cgm-remote-monitor:latest
NIGHTSCOUT_SOURCE_MODE=image
NIGHTSCOUT_UPSTREAM_DIR=./upstream/cgm-remote-monitor
MONGO_IMAGE=mongo:6
MONGO_CONTAINER_NAME=shared-mongo
MONGO_ROOT_USERNAME=admin
MONGO_ROOT_PASSWORD=change-me
MONGO_PORT=27017
NGINX_IMAGE=nginx:1.27-alpine
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443
```

## Per-site env files

Each site keeps standard Nightscout configuration in its own env file, for example:

```dotenv
API_SECRET=replace-me
DISPLAY_UNITS=mmol
ENABLE=careportal,bgdelta,basal,profile,iob,cob
AUTH_DEFAULT_ROLES=readable
```

`MONGO_CONNECTION` and `MONGODB_URI` are generated automatically from the inventory and do not need to be repeated inside each site env file.

## Backups

Back up every hosted site database:

```bash
./scripts/backup-all.sh
```

Outputs are written to `./backups/<timestamp>/`.

## Updates

If you use the upstream image:

```bash
docker compose -f compose.yaml -f generated/compose.sites.yaml pull
docker compose -f compose.yaml -f generated/compose.sites.yaml up -d
```

If you use a cloned upstream checkout:

```bash
./scripts/pull-nightscout-upstream.sh
docker compose -f compose.yaml -f generated/compose.sites.yaml build
docker compose -f compose.yaml -f generated/compose.sites.yaml up -d
```

Safer rollout:

1. Back up all databases.
2. Update your own site first.
3. Verify uploaders, charts, auth, and treatments.
4. Roll out to the remaining sites.

## Notes

- Mongo is only attached to `mongo-net` and is not published directly to the internet.
- Nightscout containers are attached to both `proxy-net` and `mongo-net`.
- This repo does not patch Nightscout itself. It gives you a maintainable multi-site hosting layout while preserving upstream compatibility.
