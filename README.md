# multi-user-nightscout

This project is a simpler way to run multiple Nightscout sites in Docker without needing a separate MongoDB container for every single user.

The main goal is to reduce complexity and RAM usage while keeping each Nightscout site separate and as close as possible to the original Nightscout design.

Run many upstream Nightscout instances with:

- one shared MongoDB container
- one Nginx reverse proxy
- one database per site
- one Nightscout container per site
- two Docker networks instead of dozens

Instead of this:

- 1 Nightscout container
- 1 MongoDB container
- 1 Docker network
- repeated again and again for every user

this project changes the setup to:

- 1 shared MongoDB engine
- many Nightscout containers
- 1 separate Mongo database per Nightscout site
- a much smaller number of Docker networks to manage

This matters because MongoDB uses memory. If you run lots of separate MongoDB containers, you waste RAM on duplicated database engines. By running one MongoDB engine with many separate databases inside it, you can host more Nightscout sites on less RAM.

This repo is intentionally a Docker orchestration layer around the official Nightscout project. You can either:

- pull the published upstream image from Docker Hub
- or clone the official Nightscout repo locally and build from that checkout

That gives you a clean way to host many sites without maintaining your own app fork.

## Purpose

The purpose of this repo is to make multi-site Nightscout hosting simpler.

It is designed for people who want to host several Nightscout sites in Docker and want:

- less RAM usage
- fewer MongoDB containers
- fewer Docker networks
- a cleaner update path
- to stay close to the original Nightscout project

This project does not try to turn Nightscout into a completely new custom app.

Instead, it keeps the original Nightscout model:

- one Nightscout app per site
- one database per site
- one set of site-specific settings per site

The difference is that many separate site databases now live inside one shared MongoDB engine.

## How It Works

Each user still gets their own Nightscout site.

Each site still has its own:

- hostname
- API secret
- Nightscout settings
- Mongo database

So from the Nightscout app's point of view, it still behaves much like a normal standalone Nightscout install.

The main change is underneath:

- before, each site had its own MongoDB container
- now, all sites share one MongoDB engine
- but each site stores its data in its own separate database

Example:

- `jay.example.nz` uses database `ns_jay`
- `bob.example.nz` uses database `ns_bob`
- `alice.example.nz` uses database `ns_alice`

This helps preserve the original functionality and separation of the original Nightscout project while making the hosting environment much more efficient.

## Why This Uses Less RAM

If you run 20 or 50 separate MongoDB containers, each one has its own memory overhead.

That means the server is spending RAM on:

- many MongoDB processes
- many caches
- many container overheads

With this project, you run one MongoDB engine and many databases inside it instead.

That means:

- fewer running database processes
- less duplicated overhead
- simpler backups
- simpler monitoring
- simpler upgrades

The result is that you can usually host more Nightscout sites on the same machine.

## Security And Separation

Even though the MongoDB engine is shared, the intention is still that each user's data remains separate.

That separation is achieved by giving each site its own dedicated database.

So:

- Jay's Nightscout reads and writes `ns_jay`
- Bob's Nightscout reads and writes `ns_bob`
- Alice's Nightscout reads and writes `ns_alice`

That preserves the original Nightscout structure much better than trying to put all users into one shared set of collections.

In other words:

- shared MongoDB engine
- separate database per site
- original Nightscout behavior preserved as much as possible

This repo currently generates connection settings automatically. A further hardening step for production is to use a separate MongoDB user per site so each Nightscout container can access only its own database.

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

## Standalone vs Shared Model

Traditional Nightscout hosting usually looks like this:

- `nightscout-jay` -> `mongo-jay`
- `nightscout-bob` -> `mongo-bob`
- `nightscout-alice` -> `mongo-alice`

This project changes that to:

- `nightscout-jay` -> shared Mongo database `ns_jay`
- `nightscout-bob` -> shared Mongo database `ns_bob`
- `nightscout-alice` -> shared Mongo database `ns_alice`

So you are not combining users into one Nightscout app.

You are running:

- one Nightscout container per site
- one database per site
- one shared MongoDB engine underneath them all

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

This is the easiest path for new users because there is no migration step.

You are simply creating a normal Nightscout site that starts life on the shared MongoDB engine from day one.

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

This is the safer path for existing users because it gives you a rollback option if anything is wrong.

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
- The main benefit is operational simplicity: more Nightscout sites, fewer MongoDB containers, and lower overall RAM overhead.
