
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

   Ralationships are established as:

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

