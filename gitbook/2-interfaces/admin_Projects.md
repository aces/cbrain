Projects are used to store files and tasks and they facilitate the sharing of files and resources between users. There are four types of projects:
* **System projects**: every user on CBRAIN is automatically a member of the system project.
* **Site projects**: every member of a site is automatically a member of the site project.
* **User projects**: every user is automatically assigned a user project, specified by the user's username.
* **Work projects**: A work project can be created by any user. It represents a group created for the purpose of assigning collective permission to resources (as opposed to SystemGroup).

The system, site and user projects are all created automatically by CBRAIN.

## How to create a Project

* Go to the "Projects" section.
* Open the "Create project" panel.
* Fill the form:
  * **Name**: Name of the project
  * **Description**: First line should be a short description, which will be used in the project index table. After that you can add any special note for the user.
  * **Site**: The projects can be associated with a specific site.
  * **Invisible**: A project can be made invisible to a `NormalUser`. This type of project is used to share some resource, for example, an Execution Server or Data Provider.
  * **Active users**: This table can be used to add users one by one.
  * **Locked users**: By default these users are hidden in order to reduce the size of the table containing the active users.
  * **Quick select based on other * Projects**: You can select users by selecting an other Project.
* Click on "Create".

## Delete a project

All Userfile, RemoteResource and DataProvider associated with the group being destroyed will have their group set to their owner's SystemGroup.

**Note**: Original author of this document is Natacha Beck