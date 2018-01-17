A tool is a generic entry in CBRAIN, which contains a range of information to distinguish different 
tools from one another. Usually a tool has a "Tool Config". 

There are three categories of tool config:
* A tool config can be associated with a particular execution server only. In this case it 
  represents the initialization for all tools on a particular execution server.
* A tool config can be associated with a particular tool only. In this case it represents the 
  initialization for a particular tool on all of the execution servers.
* A tool config can be associated with an execution server and a tool. In this case 
  it represents the initialization for a particular tool, on a particular execution server.

## Autoload Tools

Once a new tool has been added to the code base of CBRAIN, the new tool should be registered by clicking the "Autoload Tools" button on the "Tools" tab.

The following information is shown for the tool:
* **Name**: The name of the tool, based on the CbrainTask class, for example for 
`CbrainTask::Diagnostics` the name is `Diagnostics`.
* **CbrainTaskClass**: The class of the task, for example, `CbrainTask::Diagnostics`.
* **User ID**: The `id` of the owner of the tool. This is the `id` of the user who clicked the "Autoload Tools" button.
* **Group ID**: All the members of this project have access to the tool. This is the 'UserProject' of the person who clicked the "Autoload Tools" button (for more information see the [Projects](admin_Projects.html) page).
* **Category**: By default the tool is a "scientific tool".

**Note**: For information on the programming side about adding a `CbrainTask', see 
the [CbrainTask Programmer Guide](../3-programmer/cbrain-task/CbrainTask-Programmer-Guide.html).


## How to create a Tool

* Go to the "Tools" tab.
* Click "Create New Tool".
* Fill in the form:
  * **Tool Name**: The name of the tool. This can be any name, but in the original platform it is 
    generally based on the CbrainTask class.
  * **CbrainTask Class**: The CbrainTask class should correspond to the CbrainTask class used in the code, 
    for example `CbrainTask::Diagnostics`.
  * **Belongs to**: The owner of the tool.
  * **Available to members of project**: Access to a tool can be limited to members of a 
      particular project. For more information, see the [Projects](admin_Projects.html) page.
  * **Category**: Choose the type of tool from three different categories:
    * *Background*: This type of tool is not called directly by users.
    * *Conversion tool*: This type of tool performs conversion between two formats.
    * *Scientific tool*: This type of tool performs more advanced tasks.
  * **License agreements**: One license agreement name should be listed on each line. For more information, 
      see the [Custom Licenses](admin_Custom-Licenses.html) page.
  * **Description**: The first line should be a short description, which is used in the "Tools" table. After 
     that any special note for the users can be added.
  * **Text for select box on the userfiles page**: This text is displayed on the "Files" tab when a 
      user launches a task.

## How to create a tool config

There are three types of tool configuration.
This section describes how to create each of these and the purpose of each type.

**Note**: When you edit or create a tool config, you can always use the **Merge configuration from another existing entry** to create a new entry. Sometimes it is easier to do it this way.

#### Tool config associated with an execution server only

This type of tool config represents the initialization for all tools on a particular execution server. 
To create or edit the tool config:
* Go to the "Servers" tab.
* Click on the execution server for which you want to add/edit a tool config.
* Click "Edit" in the "Cluster Configuration" section.
* Click "Edit" or "Create" after "Common configuration for all tasks".
* You are redirected to a form, where you can fill in the following:
  * **Environment variables needed for this tool**: Environment variables are defined.
  * **BASH initialization prologue**: This is a multi line partial BASH script, which uses the environment variables defined above.

#### Tool config associated with a tool only

This type of tool config represents the initialization for a particular tool on every execution server. 
To create or edit this tool config:
* Go to the "Tools" tab.
* Click on the tool for which you want to add/edit a tool config.
* Click on "Edit" after "Common configuration for all servers".
* You are redirected to a form, where you can fill in the following:
  * **Environment variables needed for this tool**: Environment variables are defined.
  * **BASH initialization prologue**: This is a multi line partial BASH script, which uses the environment variables defined above.

#### Tool config associated with an execution server and a tool

This type of tool config represents the initialization for a particular tool, on a particular execution server.

To create the tool config:
* Go to the "Tools" tab.
* Click on the tool for which you want to add/edit a tool config.
* Below the heading, "Versions installed on the following execution servers", there is a list of 
  execution servers.
* Below each execution server there is a "Add new" link to define a new tool config.

To edit the tool config:
* Go to the "Tools" tab.
* Click on the tool for which you want to add/edit a tool config.
* Below the heading, "Versions installed on the following execution servers", there is a list of execution servers.
* For each execution server there is a list of tool configs for the tool. There are three links after 
  each tool config, to "Edit", "Show" or "Delete" the contents of the tool config.

Fill in the form:
* **Available to members of project**: Access to a tool can be limited to members of a particular project.
    For more information, see the [Projects](admin_Projects.html) page.
* **Version**: Enter a tool version when a tool has different options or behavior depending on the version.
* **Description**: The first line should be a short description, which is used in the Tool config table.
  After that, any special note for the users can be added.
* **Suggested number of CPUs to use in parallel, per task**: This depends on the number of CPUs of the 
  execution server.
* **Environment variables needed for this tool**: Environment variables are defined.
  * **BASH initialization prologue**: This is a multi line partial BASH script, which uses the environment variables defined above.

## How to view a tool config

To view a particular tool config associated with a tool and execution server:
* Go to the "Tools" tab.
* Click on the tool for which you want to see a tool config.
* Bellow the heading, "Versions installed on the following execution servers", there is a list of 
  execution servers.
* Click the "Show" link.

This page lists the name of the tool config, the tool version and execution server that it applies to, as well as the availability to users and the number of suggested CPUs to be used.  The full BASH initialization prologue script for the configuration is also shown.

## Reports

The Tools index page shows links to the "Access Reports" and the "Access?" report by tool. Consult the [Reports And Monitoring](admin_Reports-And-Monitoring.html) section of this guide for more information about the reports.

**Note**: Original author of this document is Natacha Beck