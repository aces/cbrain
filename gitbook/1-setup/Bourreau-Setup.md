This document is the third section of three explaining how to 
install the CBRAIN platform:

  [Common Setup](Common-Setup.html) -> [BrainPortal Setup](BrainPortal-Setup.html) -> **Bourreau Setup**

For a general overview of these documents, please refer to
the the [Setup Guide](Setup-Guide.html).

This particular document explains how to install the UNIX environment
and files specific to the _Bourreau_ Rails application. A
CBRAIN installation can contain several Bourreaux, each one deployed
where a particular execution environment is needed.

## Bourreau Application

We assume that the code has been deployed and the files
configured according to the previous steps in the guide. 
At this point, the remaining configuration steps for a Bourreau 
server can mostly be performed from the within the BrainPortal interface, 
but there is one exception: the SSH connection between the two applications.

## SSH setup

The BrainPortal needs to be able to SSH to the host
where the Bourreau application is installed. This is
true even in a development environment where the
Bourreau is running on the same host, under the same user,
and side by side on the file system.

Since CBRAIN uses its own SSH key for all communications,
it is necessary to install the key in the UNIX user account of
the host where the Bourreau is installed. For the sake
of generality we define the following four concepts:

* `puser`: The UNIX _username_ under which the *BrainPortal* is installed.
* `phost`: The _hostname_ where the *BrainPortal* is installed.
* `buser`: The UNIX _username_ under which the *Bourreau* is installed.
* `bhost`: The _hostname_ where the *Bourreau* is installed.

Note that `puser` could be the same as `buser` and `phost` could
be the same as `bhost`. This is common in a development environment.

The SSH key created by the BrainPortal when you first
booted it is in `puser_home/.ssh/id_cbrain_portal.pub` (this
is the public key of the key pair; leave the other one
alone). The content of the key file is a single long
line that you must copy to the other `buser` account
and append to the file `buser_home/.ssh/authorized_keys`.
If the file does not exist, create it and verify that its
privileges are set to 600 (a.k.a `rw-------`). These
commands, sent from `phost` (where the BrainPortal
is installed) do the following:

```bash
cd $HOME/.ssh
cat id_cbrain_portal.pub | ssh buser@bhost 'cat >> .ssh/authorized_keys;chmod 600 .ssh/authorized_keys'
```

You will likely be prompted to enter the password to connect to the remote
site.

If all is well, it should now be possible to SSH to the UNIX account where
the Bourreau is installed without having to enter a password. Try it
from the BrainPortal side and _make sure that no password is requested_ this time:

```bash
ssh buser@bhost hostname  # attempting to run the 'hostname' command remotely
```

Finally, verify that running a non-interactive SSH command such as 
that shown above works within the RVM environment on the Bourreau 
side. This can be done using the following command:

```bash
ssh buser@bhost rvm info
```

If a message is shown, such as `rvm: command not found`, or the 
`rvm info` output does NOT list the same thing as when you connect
interactively to `bhost`, then it is necessary to modify the bash initialization
files. A standard RVM installation typically adds a line at the
bottom of ".bash_profile" or ".profile" on `bhost`, which should be
similar to this (but there is no guarantee that it will match perfectly):

```bash
[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*
```

Verify while still on 'bhost' that this line is in the ".bashrc" file, usually near
the bottom, and that it is executed when you run 'rvm info'
remotely as explained above. Once this is done, you can be certain
that any commands sent by the BrainPortal Rails server to the Bourreau
Rails server using a SSH command is invoked within RVM with its gems
and Ruby.

## Bourreau configuration

Assuming that you have properly installed the Bourreau application's
code, named it and made sure you can SSH to its installation
location with RVM properly activated, it is now possible to configure it 
using the BrainPortal interface. Log in as admin, go back to the Server 
index page (click on the 'Servers' tab), and click on `Create New Server'
to bring up the required form.

The full description of the content of this form can be found in
the `Execution Servers` guide, but for the moment we fill in
only the minimum set of fields necessary to configure a
Bourreau server.

* In the `Info` section:
  * **Name**: Use exactly the same name that is in the file `Bourreau/config/initializers/config_bourreau.rb`
* In the `SSH Remote Control Configuration` section:
  * **Hostname**: The UNIX hostname where the Bourreau is installed (equivalent
    to `bhost` in the instructions above).
  * **Username**: The UNIX username on the host (equivalent to `buser`).
  * **Port Number**: This is optional and usually 22 for SSH. If the SSHD server listens
    on a different port, specify it here.
  * **Rails Server Directory**: The full path where the Bourreau
    Rails application code is installed, for instance, `/home/user/cbrain/Bourreau`.
* In the `Tunnelling Configuration` section: (see also [Communications](Communications.html))
  * **Database Server Remote Tunnel Port**: The choice of port number is arbitrary
    and can be any number between 1024 and 65535. The Bourreau application uses 
    this port on the remote host to connect back to the MySQL server used by 
    BrainPortal. The tunnel is set up automatically, so it is only necessary to make 
    sure that this port number is not in use by any other application on the host 
    where the Bourreau runs.
  * **Active Resource Remote Tunnel Port**: Again, the choice of port number 
    is arbitrary, but this time the port is open on the BrainPortal side
    and allows the BrainPortal to send commands the Bourreau side.
* In the `Cache Management Configuration` section:
  * **Path to Data Provider caches**: Just like the BrainPortal application, each
    Bourreau needs its own directory where it can cache data. Create a new empty
    directory on the Bourreau's host and enter its full path here. As usual, make
    sure this directory is not shared with anything else and not even used as
    a cache by any other CBRAIN Rails application. If the Bourreau is on
    the frontend of a supercomputer, this directory should be on a filesystem
    visible from all the compute nodes of the supercomputer.
* In the `Cluster Management System Configuration` section:
  * **Type of cluster**: The Bourreau schedules tasks on a supercomputer cluster, 
    or on your own machine. Enter the type of cluster you have access to on the 
    machine where the Bourreau is installed. Typically, supercomputers have cluster 
    management systems with names such as _SGE (Sun Grid Engine)_, _Torque_ or 
    _MOAB_. UNIX can also be selected, in which case no cluster management 
    system is used, but the Bourreau simply launches the tasks as standard UNIX 
    processes. This is usually a very good choice for a programmer's development 
    environment.
  * **Path to shared work directory**: Just like for the cache directory, this needs
    to be configured with the full path to an empty directory created on the Bourreau 
    side. And again, it must not be shared with any other resource. This directory is 
    the location where subdirectories are created for each task launched on this Bourreau. 
    If the Bourreau is on the frontend of a supercomputer, then this directory should be 
    on a filesystem visible from all the compute nodes of that supercomputer.  For a 
    programmer's personal development environment, any new empty directory is fine.
* In the `Bourreau Workers Configuration` section:
  * **Number of workers**: Configure a small number of worker subprocesses that
    are launched on the Bourreau side to handle the tasks running there. On a
    development machine, a single worker checking the task list once every 10
    seconds is a good choice. On the production frontend of a supercomputer, with
    tasks lasting several hours each and dozens of users simultaneously submitting
    new ones regularly, it would be appropriate to have 3 or 4 workers checking the 
    task list once per minute or even less.

After editing each section, click 'Update' to save the values.

## Moving on

At this point you can start and stop the Bourreau application
using the BrainPortal web interface. Go to the 'Servers' tab
and find the Bourreau's name on the list. Clicking the
'start' link in that row initiates the following steps:

  * The portal establishes a persistent SSH master connection
    to the host where the Bourreau is located (see also [Communications](Communications.html)).
  * Through the SSH connection, it sends some shell commands
    to create a temporary `database.yml` file in the `Bourreau/config`
    subdirectory and starts the Bourreau Rails application.
  * If successful, it also sends the Bourreau a special
    CBRAIN command to start its Worker subprocesses.

The Bourreau is ready to accept tasks once CBRAIN Tools
are configured for it by the CBRAIN administrator.

**Note**: Original author of this document is Pierre Rioux