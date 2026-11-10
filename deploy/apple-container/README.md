# Local CBRAIN with Apple container

This runs BrainPortal, a local Bourreau (`ScirUnix`), and MariaDB in three
ARM64 Linux containers. It uses Apple's `container` CLI;
Docker Desktop and Docker Compose are not needed. `Containerfile` uses the OCI
build syntax accepted by Apple container; `.dockerignore` is its build-context
exclusion file.

## Start

Requires an Apple silicon Mac running macOS 26 or newer and Apple's `container`
CLI on `PATH`. Install the signed package from the
[Apple container releases](https://github.com/apple/container/releases).
The launcher checks these prerequisites before invoking container commands or
creating local state, and explains how to resolve a missing prerequisite.
The `credentials` command can still read saved credentials without the runtime.

From the repository root:

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

To recreate the worker while retaining its work directories and host key:

```sh
container stop cbrain-bourreau
container delete cbrain-bourreau
deploy/apple-container/apple-container.sh up
deploy/apple-container/apple-container.sh smoke
```

Wait for active tasks to finish before stopping the worker. `up` discovers its
new address and reconnects the portal.

## Persistence and rebuilds

- `cbrain-db-data`: MariaDB database.
- `cbrain-app-data`: provider files, portal cache, SSH identity and host key,
  and portal logs.
- `cbrain-bourreau-data`: task work directories, worker cache, SSH host key,
  and Bourreau logs.
- `.local/apple-container/env`: generated passwords and session secret, mode 600,
  excluded from Git and the image. Keep this file with database backups.

`stop` preserves containers and volumes. If MariaDB receives a new IP on restart,
`up` recreates the portal container with the new address and reuses its data
volume. Repeated startup runs migrations and ensures the local resources exist.
The admin password is set when the database is first seeded.
Source code is copied into the image. Rebuild and recreate both app
containers after code changes while keeping their volumes:

```sh
deploy/apple-container/apple-container.sh build
container stop cbrain-bourreau cbrain-app
container delete cbrain-bourreau cbrain-app
deploy/apple-container/apple-container.sh up
```

On upgrade from the combined container, build the new image and run `up`.
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

## Optional Slurm profile

Select the Slurm profile in a separate shell:

```sh
export CBRAIN_LOCAL_PROFILE=slurm
deploy/apple-container/apple-container.sh build
deploy/apple-container/apple-container.sh up
deploy/apple-container/apple-container.sh smoke
```

Open <http://localhost:3003>. Use the same launcher commands (`credentials`,
`status`, `logs`, and `stop`) with the profile selected. The profile uses its
own containers, volumes, credentials, and database under the `cbrain-slurm`
prefix and `.local/apple-container/slurm` state directory.

Bourreau uses `ScirSlurm` and submits jobs to the separate
`cbrain-slurm-node` container. That container runs the Slurm controller,
compute daemon, and accounting daemon. Accounting uses a dedicated schema
in the profile's MariaDB. Bourreau and the compute node mount the same
`/cluster` directory for job work, cache, and Slurm configuration. Keep
the profile's state directory with its volumes to preserve that data and
the Munge key.

The Slurm image includes ARM64 Apptainer 1.5.5. For a containerized tool, set
the Tool Config's container engine to **Singularity** and select an ARM64
image. For an OCI source, use `docker://` as the index location. Bourreau
builds and caches a SIF under `/cluster/cache`, then stages it for the Slurm
job to run on the compute node. The default Diagnostics smoke test uses the
plain tool configuration.

To update an existing Slurm deployment, let active jobs finish, then run
these commands with the Slurm profile selected. The database, named volumes,
and shared cluster directory are retained.

```sh
deploy/apple-container/apple-container.sh build
deploy/apple-container/apple-container.sh stop
container delete cbrain-slurm-bourreau cbrain-slurm-node cbrain-slurm-app
deploy/apple-container/apple-container.sh up
```

Inspect scheduler state and job history:

```sh
container exec -e SLURM_CONF=/cluster/slurm.conf cbrain-slurm-bourreau sinfo
container exec -e SLURM_CONF=/cluster/slurm.conf cbrain-slurm-bourreau sacct -X
```

The node has two CPUs and a one-hour job limit. It uses Slurm's process-based
tracking with cgroup enforcement disabled. Allow about 9 GB of memory for
the running services.
