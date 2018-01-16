CBRAIN contains two different types of servers:

* **[Portals](admin_Portals.html)**: These provide the web interface of the platform.
* **[Execution Servers](admin_Execution-Servers.html)**: An execution server is associated with a computing 
site and performs tasks. CBRAIN can contain several execution servers.

## The index table

On the index page you will find one line for each portal or for each execution server.
The following information is shown:
* **Server Type**: The type of server, which can be a portal or an execution server.
* **Server Name**: The name of the server.
* **Live Revision**: The revision of the server. Highlight in red if the version is not the same as the portal.
* **Owner**: The owner of the server.
* **Project**: The project associated with the server.
* **Site**: The site associated with the server.
* **Time Zone**
* **Online?**: If an execution server is offline, then there is a red "Offline" message 
  in this column.
* **Uptime**: The time since the server has been working and available.
* **Workers**: The number of workers for the server.
* **Tasks**: The number of tasks on the server. This is a hot link to the Tasks table with 
an appropriate filter set in order to see only the tasks on this particular server.
* **Tasks Space**: The task space for the server.  This is a color coded hot link
(black to red) that points to a custom report with the size of the task space for the user 
on the server.
* **Description**: A short description of the server.
* **Status page URL**: An external link to a page with information about the status of 
the cluster.  **Note:** You can not set this link when you first create a new server. So 
you should first create the server and then edit the information about the server afterwards.
* **Operation**: You can directly start or stop an execution server from the index page.


## Reports

On the Servers index page there are links to different reports, such as the "User Access 
Report" and the "Disk Cache Report". Consult the [Reports And Monitoring](admin_Reports-And-Monitoring.html) section of this 
guide for more information about the reports.

**Note**: Original author of this document is Natacha Beck