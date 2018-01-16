This document is a step by step guide to installing and configuring the core CBRAIN 
framework on your site.

This document can be used to install either:

* A personal CBRAIN server for development by an individual programmer, or
* A production server for multiple users.

It is assumed that the person reading this document is a reasonably competent UNIX
user, familiar with command-line environments, as well as typical system
administration concepts such as libraries, packages, filesystem paths, networking and
environment variables.

All commands shown in this guide use the _bash_ command-line interpreter.


## A distributed system

A CBRAIN installation is a graph of components connected through the network.
There are four types of components:

  * A database (MySQL or MariaDB) to manage everything.
  * A _BrainPortal_, which is a Rails application that provides a web interface.
  * A set of _Bourreaux_, which are also Rails applications, each
    running at a computing site (whether this is a supercomputer or desktop server).
  * A set of _DataProviders_, which are abstractions for file storage areas.
    DataProviders can be installed on the same computer as the BrainPortals,
    the Bourreaux or on other UNIX systems elsewhere.

Here is a diagram of all these components with their typical layout:

[![CBRAIN Components](images/CbrainComponents.png)](images/CbrainComponents.png)

A programmer planning development on the platform might configure
the components that are on the left side of the diagram on his workstation:
a BrainPortal, a Bourreau and a local DataProvider.

More components would typically be installed on a production server;
most likely there would be Bourreaux on servers for running tasks and Data 
Providers on them for storage.

## Code organization

A note about the organization of the source code, as it is distributed. 
Once extracted there are two main subdirectories, "BrainPortal" and "Bourreau".
These are the two main Rails applications within the CBRAIN installation.
Most of the files in the Bourreau branch are actually symbolic links
to the same files on the BrainPortal side. This is to avoid duplicating
these files, since these two applications share a lot of code.

When deploying any of the components shown in the diagram above, it is
necessary to perform one extraction of the full source tree (both
applications) for each BrainPortal or Bourreau. If you install
several Bourreaux, even on the same server and under the same UNIX
username, you need to extract the source code separately.

## Overview of installation

The installation documentation is split into three separate guides.
Building a CBRAIN installation is done incrementally, whether you are setting up
a personal development CBRAIN or a production installation.

#### For a personal development environment

Follow the steps in these two guides only once:

  [Common Setup](Common-Setup.html) -> [BrainPortal Setup](BrainPortal-Setup.html)

Next, set up a single development Bourreau using the `Bourreau` 
subdirectory that is directly next to the BrainPortal which has 
just been set up:

  [Bourreau Setup](Bourreau-Setup.html)

If you plan to add any other Bourreaux to the installation,
connect to the computers where you will set them up and follow
the steps in these two guides for each of them:

  [Common Setup](Common-Setup.html) -> [Bourreau Setup](Bourreau-Setup.html)

#### For a production environment

Again, follow the steps in these two guides only once:

  [Common Setup](Common-Setup.html) -> [BrainPortal Setup](BrainPortal-Setup.html)

Then, connect to each of the servers where you plan to
install the Bourreaux and for each of them, follow
these steps:

  [Common Setup](Common-Setup.html) -> [Bourreau Setup](Bourreau-Setup.html)

Remember that you cannot reuse the `Bourreau` directory
branch between distinct Bourreau applications that you want to
configure.