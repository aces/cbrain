# Local CBRAIN with Apple container

This runs BrainPortal and a local Bourreau (`ScirUnix`) inside an ARM64 Linux
container, with MariaDB in a second container. It uses Apple's `container` CLI;
Docker Desktop and Docker Compose are not needed. `Containerfile` uses the OCI
build syntax accepted by Apple container; `.dockerignore` is its build-context
exclusion file.

## Start

From the repository root, with Apple container installed:

```sh
deploy/apple-container/apple-container.sh build
deploy/apple-container/apple-container.sh up
deploy/apple-container/apple-container.sh credentials
```

Open <http://localhost:3000> and sign in as `admin` using the generated initial
password. CBRAIN asks you to change it on first login. The initial password
command does not track subsequent password changes.

The setup creates `LocalPortal`, `LocalBourreau`, `LocalStorage`, and local
Diagnostics, Parallelizer, and CbSerializer tool configurations. The worker runs
UNIX jobs inside the app container. Scientific tools and their datasets must be
installed/configured separately.

```sh
deploy/apple-container/apple-container.sh status
deploy/apple-container/apple-container.sh smoke  # runs Diagnostics and verifies a saved report
deploy/apple-container/apple-container.sh logs
deploy/apple-container/apple-container.sh shell
deploy/apple-container/apple-container.sh stop
deploy/apple-container/apple-container.sh up
```

Only port 3000 is published, on `127.0.0.1`. SSH is internal to the app container;
MariaDB is on the private `cbrain-local` network. Both Rails apps share the app
container to keep local UNIX jobs, SSH tunnels, and file paths straightforward.

## Persistence and rebuilds

- `cbrain-db-data`: MariaDB database.
- `cbrain-app-data`: uploaded files, job work directories, caches, SSH identity,
  and startup logs.
- `.local/apple-container/env`: generated passwords and session secret, mode 600,
  excluded from Git and the image. Keep this file with database backups.

`stop` preserves containers and volumes. If MariaDB receives a new IP on restart,
`up` recreates the app container with the new address and reuses its data volume. Repeated startup runs migrations and
ensures the local resources exist; it does not reseed or reset an existing admin
password. Source code is copied into the image, so rebuild after code changes.
To replace the app container after a build while keeping all data:

```sh
container stop cbrain-app
container delete cbrain-app
deploy/apple-container/apple-container.sh up
```

This is a local development deployment. The upstream application uses Rails 5.0
and Ruby 2.7, and the Ruby image requires Debian's Bullseye archive. Do not expose
this deployment publicly. Budget approximately 5 GB RAM for the running services
plus the image builder during builds.

The smoke check leaves its completed task and Diagnostics report in CBRAIN so
you can inspect them in the portal. Each invocation creates one small report.
