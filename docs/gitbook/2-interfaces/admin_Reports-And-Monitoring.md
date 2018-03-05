To help the platform administrators, CBRAIN has many reports in different
locations, which are not readily visible to the user. This section describe all 
such reports. CBRAIN also has a comprehensive mechanism for tracking activity on the platform.

## Automatic tabular Report maker

The "Report maker" can generate many different kinds of reports in a tabular
layout (e.g. reports about 'UserFile' or 'DataProvider'). This is a modular way
to generate different reports.

To use the "Report maker":
* Go to "My Account" tab.
* Click on "Report Maker".
* Select "Report type" in the gray box. Most reports count the number of objects
  that are accessible, but some of them perform summation of some attributes.
* Click "Lookup columns and rows" and the form is adjusted to show which
  attributes can be selected for the rows and columns of the table.
* Select an attribute for the rows and columns using each of the selection boxes
  shown at the top and left of the table area.
* Click "Generate report" and a table is created with hot links to the
appropriate index pages for the objects. You can modify the report's properties
and regenerate it at any time.
* Optional filters can be added in order to refine the report.

## Tools report

#### Access reports

"Access reports" generates reports about the tools.

To use "Access reports":
* Go to the "Tools" tab.
* Click "Access reports".
* On this page quick links or a more specific combination can be used to show
the following reports:
  * **By execution server**: The first line of this report lists all of the
  tools not configured for the server. After that, there is a table with a
  list of tools and versions configured for the server.
  There is also information about the project associated with each tool and a
  list of users that do not have access to the tools.
  * **By tool**: The first line of this report lists all the execution servers
  where the tools are not configured. After that, there is a table with a list
  of tools and versions configured for the server, information about the project
   associated with each tool and a list of users that do not have access to the
   tools.
  * **By user**: If user is selected there are four different reports:
    * **Member of editable projects**: A table showing all the groups a user
    belongs to.
    * **Execution servers access**: A table showing execution servers accessible
    by the user.
    * **Tool access summary**: A table showing the number of tool versions
    accessible per server by the user.
    * **Tool versions access details**: A very comprehensive table showing
    the list of tools and tool versions by execution server with the associated
    projects and a column showing tool versions accessible by the user.
    This table is ideal for determining why a user cannot get access to a
    particular tool.
  * **Custom report**: A custom report can be created by selecting a particular
  execution server and/or a particular tool and/or a particular user.

#### Access

There is an "Access?" link on the index page, on the right of the table, which
can be clicked to find a link for a tool. Clicking on this latter link will
redirect to the "Access Reports" by tool.

## Data Provider reports

#### User access reports

To show "User access reports":
* Go to the "Data Provider" tab.
* Click "User Access Report".

This table has rows for users and columns for Data Providers.
Each cell of the table is a green circle when the user has access to the
Data Provider or a red cross otherwise.

#### Transfer restrictions

To show the "Transfer restrictions" report:
* Go to the "Data Provider" tab.
* Click "Transfer Restrictions Report".

This table shows which file transfers are allowed between Data Providers.
Each cell of the table has two symbols, where a green circle means allowed and
red cross means not allowed. Transfers are possible if both symbols are green
circle/green circle.

* **First symbol**: This table shows restrictions for transferring files between
Data Provider pairs, independently of the states of any other resources.
The restrictions are not necessarily symmetrical: it is possible to configure
Data Providers A and B such that transfers from A → B are allowed (green circle)
while transfers from B → A are not (red cross).

* **Second symbol**: Since transfers are performed by the CBRAIN Portal,
there are three other factors to take into account:
  * Whether or not Data Providers are online or offline;
  * Whether or not Data Providers are read/write or read only;
  * Whether or not the current Portal itself has access to each Data Provider.

In such cases, Data Providers will be annotated with "offline", "read only"
and/or "portal has no access". If all three properties allow the file transfers,
the second symbol will be a green circle; it will be a red cross otherwise.

#### Disk usage report

To show the "Disk usage report":
* Go to the "Data Provider" tab.
* Click "Disk Usage Report".

This is a custom report with rows for users and columns for Data Providers.
Each cell contains the size of the data by user and by Data Provider, and a hot
link is shown with the "Number entries/Number files". Follow the hot link to be
redirected to the Files index page with filters to show only the particular
entries that are requested. In each cell there is a color coded chip to
represent the size of the data, from blue to red.

## Server reports

#### User access report

To show the "User Access Reports":
* Go to the "Servers" tab.
* Click "User Access Report".

This is a simple table with rows for users and columns for servers. Each cell in
the table is a green circle when the user has access to the Data Provider or a
red cross otherwise.

#### Disk cache report

To show the "Disk Cache Report":
* Go to the "Servers" tab.
* Click "Disk Cache Report".

This page displays the size of the cache directory by user and server. The size
of the data is color coded from blue to red. If the user has an active task on a
particular server, a red message appears in the cell to inform the administrator.
A filter can be added to select results by date. Cleanup of the cache can also be
performed on this page.

#### Task workdir size report

To show the "Task Workdir Size report":
* Go to the "Servers" tab.
* Click "Task Workdir Size Report".

This is a custom report with rows for users and columns for servers. Each cell
contains the size of the data by user and server, with a hot link with the
"Number of tasks". Follow this hot link to be redirected to the Tasks index page,
where filters can be used to select particular entries. In each cell there is a
color coded chip to represent the size of the data, from blue to red.

#### Access to Data Providers

To show the "Access to Data Providers" report:
* Go to the "Servers" tab.
* Click "Access to Data Providers".

This page shows which servers (rows) can access which Data Providers (columns). 
Each cell in the report can show:   
1. Green circle (access is allowed)      
2. Red cross     
3. Red cross and "no access"     
4. Green circle and "no access"   
5. Question marks, with or without "no access"   

The report page can be consulted for further information on each of these options.  

"No access" means that within CBRAIN the admin disallowed the connection, 
so servers cannot access files on the Data Provider at all, neither streaming 
nor synchronized, even if the Data Provider seems alive. Number 2 and 3 are 
slightly different, since the red cross means that the transfer is supposedly 
allowed, but when a test is made it still fails for reasons outside of CBRAIN's 
control (e.g. firewall rules).

To launch tasks on a particular execution server, they should be 
configured to access files on Data Providers marked by green circles.

If a Data Provider is identified as "not syncable" (below their name), its
files can still be accessed through streaming APIs, but can never be fully
synchronized on any server. 

## Task statistics

#### Task statistics by status

To show the "Task Statistics By Status" report
* Go to the "Servers" tab.
* Select a particular execution server for which you want to show statistics.
* Click "Task Statistics By Status".

This is a custom report with rows for users and columns for number of tasks with a 
particular status. The table only shows information for the particular execution 
server that you selected. Every cell contains a hot link; if you click on it you are 
redirected to the Tasks tab, listing all of the tasks with a particular status and 
user on the execution server.

#### Task statistics by type

To show the "Task Statistics By Type" report
* Go to the "Servers" tab.
* Select a particular execution server for which you want to show
statistics.
* Click on "Task Statistics By Type".

This is a custom report with rows for users and columns for the number of 
tasks of a particular type. It only shows the information for the particular 
execution server you selected. Every cell contain a hot link; if you click on 
it you are redirected to the Tasks tab, listing all the tasks of a particular 
type, for the user and execution server you selected.

## Portal log page

To use the "Portal log page":
* Go to the "Dashboard"
* Click "View logs"

This page shows the log information received by the portal. There is an option
to use a **filter**, for example to only show the logs for a particular user,
or to **hide** some lines and only show what is most relevant.

## Log information

On each show page there is a "File info" section, where all of the changes that
have affected the object are shown. In this way an administrator can track every 
change that happen for this entry in CBRAIN.

**Note**: Original author of this document is Natacha Beck