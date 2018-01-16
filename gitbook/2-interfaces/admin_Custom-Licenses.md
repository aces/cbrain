In CBRAIN, administrators can add custom licenses for particular CBRAIN resources. A license allows an administrator to define the terms of usage for a resource, such as a particular execution server.

## Which resources can have a license

A [Portal](admin_Portals.html) can have a specific license, which makes it
necessary for every CBRAIN user to accept the terms of the license
before using the platform.  Each [Execution Servers](admin_Execution-Server.html),
[Data Provider](admin_Data-Providers.html] or [Tool](admin_Tools.html) can also have a
specific custom license. In this case, every user that can access
the resource must accept the terms of the license to continue to
use the platform.

## Format and location of license files

A license is a simple HTML file. At the beginning of the file, there is an input field "num_checkboxes"
with a value for the number of checkboxes that the user checks on the page.

Like this:

```html
<input name="num_checkboxes" type="hidden" value="3" />
```

Next, there is a description of the terms of the license in HTML format.

Finally, at the end of the file a set of checkboxes are defined (the same
number that were defined before). Each checkbox has a name beginning with
`license_check`.

Like this:

```html
<input name="license_check_1" type="checkbox" value="agree" /> Some text
<input name="license_check_2" type="checkbox" value="agree" /> Some text
<input name="license_check_2" type="checkbox" value="agree" /> Some text
```
Copy this HTML file to `BrainPortal/public/licenses` with an `.html` extension.
In the original platform, the name of the file follows this convention:
`cbrain_\d+.html` (\d+ is a string of numbers).

## How to register a license

To add a license to a resource in CBRAIN, it is necessary to register it:
* **For a portal or an execution server**:
  * Go to the "Servers" tab.
  * Select the portal or the execution server to which you want to add a license.
  * Click "Edit" in the "Info" section
  * Edit the "License agreements" box, by entering one agreement name on each line.
  * Click "Update".
* **For a Data Provider**:
  * Go to the "Data Providers" tab.
  * Select the data provider to which you want to add a license.
  * Click "Edit" in the "Info" section
  * Edit the "License agreements" box, by entering one agreement name on each line.
  * Click "Update".
* **For a tool**:
  * Go to the "Tools" tab.
  * Select the tool to which you want to add a license.
  * Edit the "License agreements" box, by entering one agreement name on each line.
  * Click "Update tool" at the bottom of the page.

**Note**: Original author of this document is Natacha Beck