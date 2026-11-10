# Local CBRAIN with Apple container

This runs BrainPortal, a local Bourreau (`ScirUnix`), and MariaDB in three
ARM64 Linux containers. It uses Apple's `container` CLI;
Docker Desktop and Docker Compose are not needed. `Containerfile` uses the OCI
build syntax accepted by Apple container; `.dockerignore` is its build-context
exclusion file.

## Start

Requires an Apple silicon Mac running macOS 26 or newer, Python 3, and Apple's
`container` CLI on `PATH`. Install the signed package from the
[Apple container releases](https://github.com/apple/container/releases).
The launcher checks these prerequisites before invoking container commands or
creating local state, and explains how to resolve a missing prerequisite.
The `credentials` command can still read saved credentials without the runtime.

From the repository root:

```sh
deploy/apple-container/apple-container.sh up
deploy/apple-container/apple-container.sh credentials
```

The first `up` builds the image and starts the services. Open
<http://localhost:3000> and sign in as `admin` using the generated initial
password. CBRAIN asks you to change it on first login. The initial password
command does not track subsequent password changes.

The setup creates `LocalPortal`, `LocalBourreau`, `LocalStorage`, and local
Diagnostics, Parallelizer, and CbSerializer tool configurations. The worker runs
UNIX jobs inside `cbrain-bourreau`. BrainPortal starts the execution server
and its task worker over SSH. Scientific tools and their datasets must be
installed/configured separately.

```sh
deploy/apple-container/apple-container.sh status
deploy/apple-container/apple-container.sh smoke  # runs Diagnostics and verifies a saved report
deploy/apple-container/apple-container.sh logs
deploy/apple-container/apple-container.sh shell
deploy/apple-container/apple-container.sh stop
deploy/apple-container/apple-container.sh up
```

Only the portal's HTTP port (3000) is published, on `127.0.0.1`. All three
containers use the `cbrain-local` network. The portal starts Bourreau over SSH
and forwards its database connection through that SSH session. Bourreau
uses the forwarded portal identity to read and write `LocalStorage` on
the portal container. The launcher installs the SSH host keys it reads
from each container.

## Persistence and rebuilds

- `cbrain-db-data`: MariaDB database.
- `cbrain-app-data`: provider files, portal cache, SSH identity and host key,
  and portal logs.
- `cbrain-bourreau-data`: task work directories, worker cache, SSH host key,
  and Bourreau logs.
- `.local/apple-container/env`: generated passwords and session secret, mode 600,
  excluded from Git and the image. Keep this file with database backups.

Run the launcher from the checkout that created the profile. Its containers
and volumes are shared across checkouts, while its credentials live in that
checkout's `.local` directory.

`stop` preserves containers and volumes. If MariaDB receives a new IP on restart,
`up` recreates the portal container with the new address and reuses its data
volume. Portal startup runs migrations, and `up` ensures the local resources exist.
The admin password is set when the database is first seeded.

After changing the source, let active jobs finish, then rebuild and restart
the deployment.

```sh
deploy/apple-container/apple-container.sh rebuild
```

`rebuild` builds the image and replaces the application containers while
keeping the database and named volumes. The `build`
command is available for building the image on its own.

On upgrade from the combined container, run `rebuild`.
The launcher replaces the combined app container, copies its work directories
and worker cache into the new worker volume, and updates `LocalStorage` to
use SSH. The provider keeps the same record and files. Its old cache status
entries are cleared so each app can resync through SSH.

This is a local development deployment. The upstream application uses Rails 5.0
and Ruby 2.7, and the Ruby image requires Debian's Bullseye archive. Do not expose
this deployment publicly. Budget approximately 7 GB RAM for the running services
plus the image builder during builds.

The smoke check leaves its completed task and Diagnostics report in CBRAIN so
you can inspect them in the portal. Each invocation creates one small report.
