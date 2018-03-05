An execution server or Bourreau is a Rails application. In CBRAIN you can configure 
as many execution servers as you want, each one corresponding to a computing site where 
tasks are performed.

## Execution server setup

Consult the [Bourreau Setup](../1-setup/Bourreau-Setup.html) documentation, for information on how to set up an 
execution server.

## How to create an execution server

* Go to the "Servers" tab.
* Click "Create New Server".
* Fill in the form:
  * **Name**: The name of the execution server. **Note**: The name must also be
    changed accordingly in the config file Bourreau/config/initializers/config_bourreau.rb for 
    the server to restart properly later on.
  * **System 'From' reply address**: This is optional. If this is set, then messages sent 
    automatically by the system contain this return adress.
  * **Description**: The first line is a short description which is shown in the Servers 
  table. After that any special note for the users can be added.
  * **Owner**: The owner of the execution server.
  * **Project**: Access to an execution server can be limited to members of a specific project. 
    See the [Projects](admin_Projects.html) section for more information.
  * **Status**: The execution server can be "online" or "offline" in CBRAIN. If the execution 
    server is created with "offline" status, then it is not accessible to users.
  * **Timeout for is alive check (seconds)**: Time after which an execution server is considered not alive.
  * **Time Zone**: The time zone of the execution server.
  * **SSH Remote Control Configuration**:
    * **Hostname**: The UNIX hostname where the execution server is installed.
    * **Username**: The UNIX username on the host.
    * **Port Number**: This is optional and is usually 22 for SSH. If your SSHD server listens
    on a different port, then specify it here.
    * **Rails Server Directory**: The full path where the Bourreau Rails application code is 
    installed, for instance, /home/user/cbrain/Bourreau.
    * **Second-level effective host**: Sometimes you will have to enter a second level of connection.
  * **Tunnelling Configuration**:
    * **Database Server Remote Tunnel Port**: The choice of port number is arbitrary and can
    be any number between 1024 and 65535.  The Bourreau application uses this port on the 
    remote host to connect back to the MySQL server used by BrainPortal. The tunnel is set up 
    automatically, so it is only necessary to make sure this port number is not in use by any 
    other application on the host where the Bourreau runs.
    * **ActiveResource Remote Tunnel Port**: Again, the choice of port number is arbitrary, 
    but this time the port is open on the BrainPortal side and allows the BrainPortal 
    to send commands the Bourreau side.
  * **Cache Management Configuration**:
    * **Path to Data Provider caches**: Each Bourreau needs its own directory to cache data. 
    Create a new empty directory on the Bourreau's host and enter its full path here. As 
    usual, make sure this directory is not shared with anything else and not even used as a 
    cache by any other CBRAIN Rails application. If the Bourreau is on the frontend of a 
    supercomputer, then this directory should be on a filesystem visible from all the compute 
    nodes of that supercomputer.
    * **Patterns for filenames to ignore**: Enter any particular pattern of filenames to 
    ignore; typically the '.DS_Store'  and the '._*' file are ignored.
    * **Cache Expiration Timeout**
  * **Tool Version Configuration**: A tool config can only be created for an existing 
    execution server. So create the execution server first and then 
    create the associated tool config afterwards. See the section about [Tools](admin_Tools.html) 
    for more information.
  * **Cluster Management System Configuration**:
    * **Type of cluster**: The Bourreau schedules tasks on a supercomputer cluster. 
    Enter here the type of cluster you have access to on the machine where
    the Bourreau is installed. Typically, supercomputers have cluster management
    systems with names like SGE (Sun Grid Engine), Torque or MOAB. UNIX can also be
    selected, in which case no cluster management system is used and the Bourreau simply 
    launches the tasks as standard UNIX processes.
    * **Path to shared work directory**: Just like for the cache directory, this
    is configured with the full path to an empty directory on the Bourreau side. 
    And again, it should not be shared with any other resource. This directory is the 
    location where subdirectories are created for each task launched on this Bourreau. 
    If the Bourreau is on the frontend of a supercomputer, then this directory 
    should be on a filesystem visible from all the compute nodes of that supercomputer.
    * **Default queue name**: Name od the queue
    * **Extra 'qsub' options**: Extra option for qsub
  * **Bourreau Workers Configuration**:
    * **Number of Workers**: Configure a small number of worker subprocesses that
    are launched on the Bourreau side to handle the tasks running there. In the original 
    platform there are usually two to four workers for each execution server.
    * **Check interval**: The interval used by the worker to check for a new task.
    * **Log destination**: Default is good for production can be changed in development.
    * **Log verbosity**: Default is good for production can be changed in development.
  * **Task Limits**: The task limits can only be defined once the execution server
   is created. Useful when you want to limit the number of active task for a specific
   execution server.

**Note**: Original author of this document is Natacha Beck