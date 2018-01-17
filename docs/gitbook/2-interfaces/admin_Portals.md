A Portal is a Rails application that provide the web-interface. In CBRAIN you can not configure a new Portal with the web-interface, you can only edit the
information about an existing Portal.

## Portal setup

In order to see how to setup a portal you should take a look to the
[BrainPortal Setup](../1-setup/BrainPortal-Setup.html) part of the documentation.

## View and Edit information

In order to view and edit the information about a portal:

* Go to "Servers" tab.
* Click on a specific portal.


There are four different sections on the page of a portal:
* **Info**: This section contain some general informtaion about the portal. You
  can edit this informations by clicking on the edit link.
  * **Name**: Name of the portal. Be carefull this one should be consistant with
  the one used during the setup part of the portal installation.
  * **Class**: Class of the portal `BrainPortal` for a portal.
  * **Owner**: The owner of a the portal, typically it is the admin user.
  * **Project**: it is useless for a portal.
  * **User Manual URL**: If set, the portal will show a link called 'User Manual'
  in the account bar at the top. It should point to a valid file accessible by the portal.
  * **Description**: First line should be a short description, which will be
  used in the Servers table. After that you can add any special note for
  the users.
  * **Status**
  * **Time Zone**
  * **Revision Info (Client Side)**: Some information about the revision, like the
  commit string, the author and the date of the revision.
  * **License agreements**: One license agreement name should be listed on each line.
  For more information, see the [Custom Licenses](admin_Custom-Licenses.html) page.
* **Mail Configuration**:
  * **Support email address**: This email address will be used when a user want
  to send an email via the "Email Support" button.
  * **System 'From' reply address**: optional, if set messages sent automatically
    by this system will contain this return address.
  * **Error notifications sent to members of project**: by default is send to all the administrator user.
* **Cache Management Configuration**:
  * **Path to Data Provider caches**: Each Portal need their own directory
    where they can cache data. Create a new empty directory on the Portal's host,
    and enter its full path here. As usual, make sure this directory is not shared
    with anything else, and not even used as a cache by any other CBRAIN Rails
    applications.
  * **Cache Expiration Timeout (in seconds)**
  * **Patterns for filenames to ignore**: You can put any type of patterns of filenames to ignore, typically the '.DS_Store'  and the '._*' file is ignored.
* **Runtime information**: this section contain a lot of information like the "Remote Host Name", the "Remote Host IP Adress"...




