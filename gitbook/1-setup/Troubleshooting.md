## Installation Issues

#### Installing the database

The [Common Setup](Common-Setup.html) guide suggest running the two rake tasks
`db:load` and `db:seed`. A typical Rails installation also comes with
a rake task named `db:setup` which is supposed to do both, includig
creating the MySQL database for you. However, please note that
you might have to comment out all the other environments defined
in `database.yml` while running this task, to leave only the one environment
you are working on. It seems sometimes `db:setup` gets confused and will read
the usernames and password fields of entries other than the one specified
by RAILS_ENV.

#### Installing Ruby on a server without root access

When installing Ruby, *rvm* will sometimes attempt to execute the commands
on your system to install system packages (such as libyaml-devel, etc).
If you're the owner of the system it will prompt you to enter an
administrative password for 'yum' or 'apt-get'. However, if you're
on a computer where you only have user access, you can't install
these packages yourself. You may have to can ask the syadmins to do it.

Sometimes, like on supercomputer clusters, the packages that *rvm* wants
to install are detected as 'missing' by *rvm*, but their files are still
perfectly installed and available to you using a command such as `module`.
In that case, if you know quite well that all the file can be found
with module, issue the appropriate `module load` commands then you can
trick *rvm* into not checking the packaging system for missing packages.
Before compiling Ruby, edit the file `$HOME/.rvm/scripts/functions/build_config`
and find an excerpt that looks like this:

```bash
  rvm_log "Checking requirements for ${rvm_autolibs_flag_runner}."
  if
    __rvm_requirements_run ${rvm_autolibs_flag_runner} "$@"
  then
    rvm_log "Requirements installation successful."
  else
```

Change the `if` condition so that it doesn't invoke the check command at all:

```bash
  rvm_log "Checking requirements for ${rvm_autolibs_flag_runner}."
  if
    true
    #__rvm_requirements_run ${rvm_autolibs_flag_runner} "$@"
  then
    rvm_log "Requirements installation successful."
  else
```

That way, *rvm* will always think your system has all the necessary package
requirements to proceed. Make sure to undo this change after you've successfully
compiled Ruby. 

## Runtime Issues

#### Mysql2 error

Some SQL queries performed by CBRAIN might fail with a message that contains these keywords:

```text 
(...) incompatible with sql_mode=only_full_group_by (...)
```

This happens more and more with modern servers. To fix this you need to change the configuration of the DB server, by removing the keyword `ONLY_FULL_GROUP_BY` from a setting called `sql_mode`. This `sql_mode` setting is a list of several keywords separated by commas. There are two ways you can do this:

* In the MySQL global configuration file (generally in `/etc/my.cnf`). The configuration file sometimes has the `sql_mode` setting explicitely stated in the `[mysqld]` section, and sometimes it isn't. If the setting isn't there, you can still create it yourself by first finding out the full value of `sql_mode` from the database's variable (see next bullet point) and removing `ONLY_FULL_GROUP_BY`.
* Directly in the database by changing the content of the ["sql_mode"](https://dev.mysql.com/doc/refman/5.7/en/sql-mode.html) variable.