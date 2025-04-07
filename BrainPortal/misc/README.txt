
=========================================================================
     Misc Directory
=========================================================================

This directory contains miscelleneous tidbits and scripts and commands
that can be (or not) useful to CBRAIN developers or administrators.

Content:

1- tst_dp.rb

   Source this in your console if you're working on developing
   a new DataProvider class; it will test the capabilities of
   the DP (upload, download, sync etc).

   tst_dp(246)    # runs the tests of your DP ID 246

   We suggest disabling SQL logs with "no_log" first (see the
   console's "cbhelp" command for more information).

2- mk_tst_access.rb and tst_access.rb

   In the console in a dev environment:

     load "mk_tst_access.rb"

   will create 4 users:

     a creator
     an editor
     a member
     a non-member

   and 8 WorkGroups, all possible combinations of the
   three boolean flags :invisible, :public, :not_assignable

   Relationships are established as:

     * All groups are created by creator,
     * All groups have creator and editor as editors.
     * All groups have creator, editor and member as members.
     * No groups have non-member as member

   in the console, typing:

     load "tst_access.rb"

   will make the program iterate over each member
   and check the list of groups returned by the methods

     groups
     viewable_groups
     listable_groups
     assignable_groups
     editable_groups
     fnp (which invokes find_neurohub_project(user))
     afnp (which invokes ensure_assignable_nh_projects() on fnb's list)

   Hitting return will move from method to method; Q to stop.

   To cleanup: see the code at the top of "mk_tst_access" to remove the
   users and workgroups.

3- background_activity/[ftr]bac.tst

These three files schedule BackgroundActivity objects ; a bunch of values
are hardcoded with IDs and names of personal development files and data providers,
you'll need to adjust these values to make this run. Normally, these files
are simply "loaded" in the console while a portal runs un background (to get
a BackgroundActiviutyWorker process running).

  tbac.rb : tests some BACs related to tasks
  fbac.rb : tests some BACs related to files
  rbac.rb : tests some BACs related to registration of files on browsable DPs

4- tst_quota.rb

This file can be loaded in a test environment to check the behavior of
the CpuQuota framework; it will pick the first NormalUser and Bourreau
configured, create dummy usage objects for them (one for the week, one
for the month, and one for the year) and then iterate through a list
of test cases for five CpuQuota objects. It's not super readable,
but it was only needed during development.

