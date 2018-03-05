This document is the first section of three explaining how to install 
the CBRAIN platform:

  **Common Setup** -> [BrainPortal Setup](BrainPortal-Setup.html) -> [Bourreau Setup](Bourreau-Setup.html)

For a general overview of these documents, please refer to
the section, "Overview of installation process", in the [Setup Guide](Setup-Guide.html).

This particular document explains how to install the UNIX environment
and files common to both the BrainPortal Rails and Bourreau Rails applications.

This document describes the initial installation steps for either:

* A personal CBRAIN server for development by an individual programmer, or
* A production server for multiple users.

It is assumed that the person reading this document is a reasonably competent UNIX 
user and familiar with command-line environments, as well as typical system 
administration concepts such as libraries, packages, filesystem paths, networking and 
environment variables.

All commands shown in this guide use the _bash_ command-line interpreter.


## About the platform

CBRAIN is a Ruby on Rails application at its core. You can find out
more about Ruby (the programming language) and Ruby on Rails (the
web-based framework) online here: [rubyonrails.org](http://rubyonrails.org)

#### The two Rails applications

There are in fact two distinct types of Rails applications in a typical CBRAIN
installation:

* A *BrainPortal* application, which provides the CBRAIN web frontend and
  most of the other capabilities of the platform.

* A *Bourreau* application, which is a simpler, lighter Rails application that
  is deployed on each of the supercomputer servers and receives commands
  from the BrainPortal application.

#### The three Rails environments

In Rails, there are _development_ and _test_ environments that
are mostly used by individual programmers working on an application.
For CBRAIN, this usually consists of a single BrainPortal
application running locally and a single Bourreau application
running alongside. In this case the Bourreau application appears
to be on a supercomputer server even though it is likely just running
on the programmer's own desktop computer.

A _production_ environment usually consists of a set of multiple
instances of the BrainPortal application running on the main web
server and a single Bourreau application running separately on
each of the supercomputer clusters that are available to users. 

As a side note, _Bourreau_ (pronounced "Boo-Row") is the French
word for an executioner (the profession) and its plural is _Bourreaux_
(pronounced exactly the same way, since the "x" is silent).


## System requirements

Before installing CBRAIN, make sure that the system meets the following
basic requirements.

#### Supported operating systems

CBRAIN has been developed and deployed successfully on two major classes 
of operating systems:

* Mac OS X, versions named Snow Leopard all the way to Mavericks
  (and it would probably work on later versions too).
* Linux, in particular the CentOS and Ubuntu distributions.

With a few adjustments to the following instructions, CBRAIN can likely 
be deployed on many other flavors of Linux or other UNIX operating systems.

#### OpenSSH

OpenSSH is normally installed on the aforementioned operating
systems. If you are using Linux and it has not been installed, use the local 
package manager to install it or ask the system administrator to do so.

#### MySQL or MariaDB

Access to a MySQL server is necessary. You can either install your own 
MySQL server or use one already available. It is necessary to have on 
the server:

* A standard user account (do not use the root account!).
* A database with full write access. This database must also be blank, 
  meaning that it exists (with any name that you choose) but
  there are *NO TABLES* in it yet.

It is outside the scope of this guide to describe the steps necessary
to set up such a system. But there is plenty of documentation online
explaining how to install a MySQL server, create an account, and 
create a database on it. Nevertheless, the basic steps for 
setting up a MySQL administrator account (assuming we are creating a 
database for a development environment) are as follows:

```sql
create database cbrain_dev;
create user     'cbrain'@'localhost' identified by 'oh-oh-this-is-a-pw';
grant all on cbrain_dev.* to 'cbrain'@'localhost';
```

Note that the database is never accessed from any other machine than
the one where the BrainPortal is installed; all the other resources
that need to access it within the CBRAIN system do so using
SSH tunnels. This is a convenient security feature, as it means the
database server never has to be directly exposed to the outside world.
More information about the communication infrastructure can be found
in the CBRAIN [Communications](Communications.html) document.

*A note about MariaDB*: the CBRAIN developers have never tested
CBRAIN on MariaDB, but are quite confident that it would work
perfectly well with it too.

#### Xcode for Mac OS X

If Mac OS X is used for development, then it is necessary to install 
Xcode. A typical Macintosh computer does not come with any development
tools and so they must be installed separately. Xcode is free and
provided by Apple as a download.

## Software installation

CBRAIN is a complex piece of Ruby software, but its installation is
made much simpler by the use of a few excellent external applications.

#### RVM

[RVM](https://rvm.io/) (Ruby Version Manager) is an all-in-one
solution for installing and managing Ruby interpreters and Ruby
libraries packaged as _gems_.  The instructions for installing RVM 
with a UNIX account can be found on the web site. We recommend setting
up a plain RVM environment without installing any other components
right away: the RVM documentation proposes an all-in-one installation
of RVM, Ruby and Rails, but here we set them up separately.

The steps are as follows:

* Install RVM itself

  ```bash
  cd $HOME
  # See the RVM home page to double-check the following command!
  # You will likely need to install a PGP key first.
  # See https://rvm.io
  \curl -sSL https://get.rvm.io | bash -s stable
  # Follow the RVM instructions...
  ```

* Log out, and then log back in (to start a new shell session) and verify
  that RVM is installed:

  ```bash
  rvm info
  ```

A report shows the version of RVM that is installed and possibly other 
system information. If instead the message `rvm: command not found` is shown, 
then either you did not log out or RVM was not installed properly.

#### Ruby

It is important to consider which version of Ruby to install. CBRAIN
has been tested and deployed on many Ruby versions including Ruby 2.2.0. This is the version that is currently 
recommended (minor upgrades to this version are fine too). Ruby versions before 2.0 may not work well.

In the following steps, RVM is used to install Ruby.

```bash
rvm install 2.2
```

This is often a step where problems occur; to install Ruby there are 
several system libraries and packages that must also
be installed and RVM attempts to install them. If you are using
a system where you do not have administrative privileges, ask the 
sysadmin to do this for you. Once these packages are installed, 
try installing Ruby again a second time.

Once Ruby is installed, use the following commands for RVM to use it 
as a default whenever you connect:

```bash
rvm use 2.2
rvm --default 2.2
```

You can run 'rvm info' again to make sure this version is selected.

#### CBRAIN code base

Next extract the CBRAIN code base to the location where you 
plan to deploy it. The easiest way to do this is to clone the 
repository directly from GitHub.

```bash
cd $HOME      # or anywhere else you prefer
git clone https://github.com/aces/cbrain.git
```

This creates a directory called 'cbrain' with all of the files
for the two Rails applications, in subdirectories named `BrainPortal`
and `Bourreau`.

#### Gems

Ruby Gems are convenient packages for Ruby libraries and applications.
A consequence of installing Ruby with RVM, as described above, is that 
you should now have access to a utility called 'bundler' which provides 
a nice front-end to installing and encapsulating a bunch of Ruby gems. If
'bundler' is not installed (you can check with 'which bundle') then
you can install it with:

```bash
gem install bundler
```

At this point the steps are different, depending on 
which of the following components you want to install:

* The *BrainPortal* application (the web frontend),
* The *Bourreau* (the execution server side application), or
* *Both* 

If you want to install the BrainPortal application, run the bundler 
from its directory and all the required Ruby Gems are installed. 
Carry out the following steps:

```bash
cd cbrain/BrainPortal   # make sure you are IN BrainPortal/ !
bundle install          # note: the command is 'bundle' without a 'r'
```

In the same way, if you want to install the Bourreau application, run the
bundler from its directory:

```bash
cd cbrain/Bourreau      # make sure you are IN Bourreau/ !
bundle install          # note: the command is 'bundle' without a 'r'
```

The BrainPortal and Bourreau side each has a particular set of gems that they
require, with some gems common to both. There are several gems that require
compilation of custom code and this is where most installation problems
occur. Often it is simply a matter of installing some development libraries
on the system. 

Here is a table of libraries that are often required:

| CentOS package name   | Ubuntu package name     |
|:----------------------|:------------------------|
| mysql-devel           | libmysqlclient-dev      |
| libxml2               | libxml2                 |
| libxml2-devel         | libxml2-dev             |
| libxslt               | libxslt                 |

There is one more step, once all of the gems are installed. Because of a
tiny bug in the install process of the gem 'sys-proctable', it is necessary 
to use the following procedure:
* Find out where the gem has been installed by the bundler.
* Go to that directory.
* Run the command 'rake install' (which modifies or copies a file,
  but may also give error messages, which can be safely ignored):
```bash
  bundle show sys-proctable
  (copy the directory shown)
  cd /to/that/directory
  rake install
```

#### Plugins installation

Some components of CBRAIN can be installed separately. They
are distributed in plugins _packages_; the structure of these
packages is described in the [Plugins Structure](../3-programmer/Plugins-Structure.html) document,
but for the moment we only install the default components 
that come with the base CBRAIN installation. If there are other 
third-party plugins packages that you want to use, extract 
them under 'BrainPortal/cbrain_plugins' first (even if right now 
you plan to install only a Bourreau).

Installing the plugins packages requires running a rake task.

For a BrainPortal:

```bash
cd BrainPortal
rake cbrain:plugins:install:all
```

For a Bourreau:

```bash
cd Bourreau
rake cbrain:plugins:install:all
```

The base CBRAIN distribution comes with a plugins package
already extracted, called "cbrain-plugins-base", which
contains some simple `Userfile` and `CbrainTask` definitions. A
CBRAIN installation would probably not work at all without
this package.

This rake task can be run many times without causing any problems.

## Moving on

At this point most of the basic files and programs needed to 
configure either the BrainPortal or Bourreau application are 
in place.

* If you are installing a BrainPortal application, then follow the
  instructions in the [BrainPortal Setup](BrainPortal-Setup.html) document.

* If you have already set up a BrainPortal and are ready
  to install a Bourreau (there can be more than one for each
  BrainPortal), then follow the instructions in the [Bourreau Setup](BourreauSetup.html) document.

**Note**: Original author of this document is Pierre Rioux