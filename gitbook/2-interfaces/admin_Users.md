A user is a person who can access CBRAIN. In CBRAIN, there are three types of user:
* `NormalUser`: a standard user who can only access his/her resources
  (e.g files or projects), or projects that he/she belongs to.
* `Site Manager`: a user with administrator rights on all of the related
  resources belonging to the site he/she manages.
* `AdminUser`: an administrator (there can be more than one administrator),
  who should have access to all parts of the system.

This section will explain how to create a CBRAIN user and particular details about users.

## How to create a User

* Go to the "Users" tab.
* Open the "Create user" panel.
* Fill in the form:
  * **Full Name**
  * **Login**: for the original platform we set a user name with
    the first letter of the first name followed by the last name, for
    example for "John Doe" we would use "jdoe". The Login should be
    unique - you can only have one user with a particular user name.
    Don't use any special characters like accents or other symbols.
  * **Email**: in order to communicate with the user if necessary.
  * **City**
  * **Country**
  * **Type**: there are three types of users, the `Normal User`, `SiteManager`, and `AdminUser`.
    Be careful to only give the status of SiteManager or AdminUser
    to people you trust. In fact, a SiteManager can do whatever he
    wants to all the resources belonging to the site he manages, and
    an AdminUser has control over ALL of the resources.
  * **Site**: see the page about [Sites](admin_Sites.html).
  * **Password**: the password should have a minimum of 8 characters
    and must have three of the following properties: an uppercase
    letter, a lowercase letter, a digit, a symbol; or be at least 15
    characters in length. You can decide that the user does not need
    to reset the password, which is a useful option if the user chose
    the password when you created the account. Otherwise the user
    will have to reset the password when logging into CBRAIN the first
    time.
  * **Projects**: In CBRAIN there are 2 types of projects. The
    `WorkProject` is generally created by the user in order to share
    data, while the `InvisibleProject` is used by the CBRAIN administrator
    in order to give access to specific resources, for example, Data
    Providers or Execution Servers. See the page about [Projects](admin_Projects.html)
    for more information.

**Note**: Necessary input fields to create a user are **full name**,
**login**, **password** and **password confirmation**. All the other
ones are optional.

## Lock or Delete a User

#### Lock a user

You can view the information about a specific user on the user's
show page, and can modify it by clicking on the "Edit" link. A
checkbox on this page also allows you to lock or unlock a User. A
locked user will no longer be able to connect to CBRAIN. You can
lock users manually.

#### Delete a user

On the show page you can find a "Delete" button that allows you to
delete the User. Note that it is not possible to delete a user that
still owns any file, execution server or data provider.
Deleting a user will destroy his/her private tags, feedback entries and
private filters.

**Note**: Original author of this document is Natacha Beck