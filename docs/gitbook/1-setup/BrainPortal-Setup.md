This document is the second section of three explaining
how to install the CBRAIN platform:

  [Common Setup](Common-Setup.html) -> **BrainPortal Setup** -> [Bourreau Setup](Bourreau-Setup.html)

To get a general overview of these documents, please refer to the [Setup Guide](Setup-Guide.html).

This particular document explains how to install the UNIX environment
and files specific to the `BrainPortal` Rails application.

## Files configuration

We assume at this point that you have deployed all the files
as described in the [Common Setup](Common-Setup.html) document.

Most of the configuration steps in CBRAIN are done within the
interface. An exception to this is the initialization of the MySQL 
database, as well as the step of setting up a few files which we will 
do right now. Both of these steps are necessary before it is possible 
to launch the interface.

#### Database connection

The database connection is defined by a single file that
_only needs to exist on the BrainPortal side_. Look in the 
`BrainPortal/config` directory for the template for 
Rail's database connection file, called `database.yml.TEMPLATE`.

Copy it to `database.yml` and edit it with your favorite text editor.

```bash
cd BrainPortal/config
cp database.yml.TEMPLATE database.yml
$EDITOR database.yml
```

There are three sections in this file, `development`, `production`
and `test`, which correspond to three Rails _environments_. Each
environment needs its own MySQL database, with its own database user.
Enter the name of the MySQL server, the database name and the user for 
each of the sections that you plan to use. These values correspond to the 
configuration of the database server, as described in the preceding 
[Common Setup](Common-Setup.html) document.

For a programmer planning to use his own workstation for development, 
it is acceptable to point the `development` and `production`
environments to exactly the same database and have a separate database
for `test`. For a full production setup, you can configure the
`production` connection profile and remove the other two.

#### Application name

Each BrainPortal application has a *name* that it uses to find
itself in the MySQL database when it runs. The name needs to be
configured as a file that the application loads.

Go to the `BrainPortal/config/initializers`
subdirectory and copy the file `config_portal.rb.TEMPLATE`
as `config_portal.rb`. **Note**: Do not simply rename it, since the
TEMPLATE file is also used by the database seeding process,
described below.

Edit 'config_portal.rb'. There is a single assignment for a 
constant named `CBRAIN_RAILS_APP_NAME`. Give the
application a simple name, such as 'AstroPortal' or 'MyDev'.

Whenever the Rails application boots, it looks up this name
in the database; both need to be kept in sync if you ever 
change the name.

#### Database schema initialization

Rails provides a mechanism to initialize your database. It
creates the full set of tables needed by your applications and
populates them with the minimal amount of data necessary to get
started. You only need to do this once and only on the BrainPortal
side (Bourreaux do not have their own database, they use one set up
on a BrainPortal elsewhere).

```bash
cd BrainPortal
rake db:schema:load RAILS_ENV=development   # creates tables
```

You need to adjust the `RAILS_ENV` value of these commands to
correspond to the environment you set up.

We assume here that the database has already been set up, as explained
above in the MySQL section.

Seeding the database is also performed by a rake task:

```bash
cd BrainPortal
rake db:seed RAILS_ENV=development # initializes the tables
```

This creates three `ActiveRecord` objects in the database:

* It reads the name of the application from the config
  file which was set up above and creates an entry for the application
  in the database (FYI: table=remote_resources, type='BrainPortal').
  This entry is incomplete and is completed later using the
  web interface.

* It creates a special default [Projects](../2-interfaces/admin_Projects.md) called 'everyone',
  which is used to assign resources that everyone can access
  (FYI: table=groups, type='EveryoneGroup').

* It creates the main admin user and assigns it a password
  (FYI: table=users, type='CoreAdmin').

The seeding process creates the password for the admin user.
_Please write it down_, since you need it to connect to the web
interface. However, if you do forget it, you can re-run the rake task later
to reset the password.

#### BrainPortal console checks

The Rails console is a great tool to inspect the entire CBRAIN
system.  For the moment, we start it once in order to initiate a 
set of validation checks.

```bash
cd BrainPortal
rails console development     # note: for the console, no RAILS_ENV=
```

which should produce something similar (but not identical to) this:

```
(Excerpt from the boot log)
C> CBRAIN BrainPortal validation starting, 2015-03-10 15:33:27 -0400
C> Rails environment is set to 'development'
C> CBRAIN instance is named 'PID-13978'
C> Hostname is 'prcent'
C>      - Note:  You can skip all CBRAIN validations by temporarily setting the
C>               environment variable 'CBRAIN_SKIP_VALIDATIONS' to '1'.
C> Ensuring that this CBRAIN app is registered in the DB...
C>      - This CBRAIN app is named 'cportal' and is registered.
C> Setting time zone for application...
C>      - Warning: time zone not set properly for this Rails app, setting it to UTC.
C> Making sure we can track file revision numbers.
C> Cleaning up old SyncStatus objects...
C>      - No SyncStatus objects are associated with obsolete resources.
C>      - No SyncStatus objects are associated with obsolete files.
C> Checking to see if Data Provider cache needs cleaning up...
C>      - SKIPPING! No cache root directory yet configured!
C> Current application tag or revision: 3.2.0-56
C> Checking for pending migrations...
C> Checking if the BrainPortal database needs a sanity check...
C>      - Error: You must check the sanity of the models. Please run this
C>               command: 'rake db:sanity:check RAILS_ENV=development'.
```

Notice that the last message is an error indicating that a sanity check
needs to be run. Run the command provided in the message:

```bash
rake db:sanity:check RAILS_ENV=development
```

Once this is done, you can start the console again:

```bash
rails console development
```

and you should get the console's prompt. You can type 'exit' to get
out of the system, unless you are familiar with Rails and want to explore
it a bit.

There are a few other important lines printed with the "C>" prefix 
during the boot process. Notice that there is a warning about a 
missing _cache root directory_ and once you started the console it 
also proceeded to _create a SSH key_, create a _SSH Agent_ 
and _create a SSH Agent Locker_:

```
(Excerpt from the boot log)
C> Checking to see if Data Provider cache needs cleaning up...
C>      - SKIPPING! No cache root directory yet configured!
(...)
C> Making sure we have a SSH agent to provide our credentials...
C>      - Created new agent: PID=4610 SOCK=/home/user/cbrain/BrainPortal/tmp/sockets/ssh-agent.portal.sock
C> Making sure we have a CBRAIN key for the agent...
C>      - Creating identity file '/home/user/.ssh/id_cbrain_portal'.
C>      - Added identity to agent from file: '/home/user/.ssh/id_cbrain_portal'.
C> Starting automatic Agent Locker in background...
C>      - No locker processes found. Creating one.
```

Let's examine these items one by one.

* The cache root directory is something which is configured with the
  web interface in the next section.

* The SSH identity file is created once for the entire lifetime of
  a particular CBRAIN installation and is used to authenticate all
  requests, local and remote, among its BrainPortal and Bourreau
  components.

* The SSH Agent is a UNIX subprocess that is involved in the authentication
  system; there only needs to be ONE such agent for the entire CBRAIN
  installation, even if multiple instances of the BrainPortal are running 
  (such as in a production environment). Whenever an instance of the BrainPortal 
  application is started, it auto discovers the SSH agent and uses it.

  This is a pretty standard UNIX 'ssh-agent' process, by the way, which can
  be found by running the following UNIX command:

  ```bash
  ps auxww | grep $USER | grep ssh-agent
  ```

* The AgentLocker is also a separate UNIX process and is also unique to
  the whole CBRAIN installation. It is a Ruby program that regularly
  'locks' the SSH Agent. The [Programmer Guides](../3-programmer/Programmer-Guides.html) have more information
  about it. It can be found using this UNIX command:

  ```bash
  ps auxww | grep $USER | grep AgentLocker
  ```

## Interface configuration

At this point it is possible to configure everything else from within 
the CBRAIN interface. First, start a local BrainPortal server:

```bash
cd BrainPortal
rails server thin -e development -p 3000
```
If all is well, more or less the same boot messages appear as were 
shown earlier when launching the console. But this time the server
sets up a network socket listening on port 3000. Open up a Web browser
and connect to the URL for the server:

`http://localhost:3000/`

You are prompted to login; the main administrative user is called
_admin_ and the password is the one given to you when you ran the
`rake db:seed` task above (which you can re-run if you forget 
the password).

Once connected, the full administrative interface is visible. For
the moment we need to configure two parameters for the BrainPortal 
application: the time zone and a path to the portal's data cache.

Go to the 'Servers' tab. This is the index page for all the
[BrainPortal](../2-interfaces/admin_Portals.html) and [Bourreaux](../2-interfaces/admin_Execution-Servers.html) on your 
system. A table is displayed, with a single entry for the current 
BrainPortal which is being used. Click on its name to view the 
information page for the BrainPortal, where each section and input 
field can be edited.

#### Time zone configuration

Click on the `(Edit)` link in the top `Info` section
and change the _Time zone_ to match the current time zone.
Click `Update` to apply the change.

#### Data cache configuration

Create an empty directory on your computer, on a filesystem
where it is possible to store a large amount of scratch data. Use your
best judgement to choose the name and location for this directory,
remembering that its purpose is to store copies of official
CBRAIN data files for the BrainPortal, for operations such as 
transfering data or viewing data with the BrainPortal interface. It 
is not simply scratch space, but it is not used to store 
important data files either.

Now, return back to the interface and the BrainPortal page you
were just editing, and find the section `Cache Management Configuration`.
Click the `(Edit)` link and enter the full path to that cache
directory in the field _Path to Data Provider caches_ .

**Note**: This directory's content is *NOT TO BE TOUCHED*
by external processes. Do no create or remove files from
the cache directory manually. The content should only be
managed by CBRAIN's BrainPortal and not shared with
other Rails applications, even within the CBRAIN installation.

## Moving on

At this point this is a functional BrainPortal application. It is possible 
to perform a number of typical actions, such as creating user accounts 
and projects. However, there is still no way to store data files anywhere 
and there are no execution servers to process them.

* Consider adding a few [Data Providers](../2-interfaces/admin_Data-Providers.html) to the installation as an admin.
  Aside from having to create an empty directory, most of the
  configuration is done right from within the interface.

* It is now also possible to install a Bourreau Rails application.
  There can be more than one for each BrainPortal and usually they
  are installed on remote supercomputer sites, but you can start by 
  configuring the one that is right beside your BrainPortal as a local 
  execution server. Follow the instructions in the [Bourreau Setup](Bourreau-Setup.html) 
  document.

**Note**: Original author of this document is Pierre Rioux