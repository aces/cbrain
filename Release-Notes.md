
## CBRAIN Release Notes

#### Version 5.2.0 Released 2019-09-13

We added a Code Of Conduct file to the GitHub repo.

New features:

- The [CARMIN API](https://github.com/CARMIN-org/CARMIN-API) has been implemented
  pretty much completely, except for some limitations (users need to find externally
  the ID of CARMIN files in order to prepare the arguments for CBRAIN tasks)
- A new DataProvider that can connect to SquashFS files through singularity
- The Travis CI control scripts have been improved and one can now selectively
  skip some test stages (e.g. just perform the Ruby curl tests...)
- Added a Boutiques descriptor as a demonstration for developers (for the command 'du')

Bug fixes:

- Several fixes for Bourreau workers
- Improvements to API (in particular, downloads of binary data)
- Big fix when changing a user's type
- Added latest Boutiques schema
- Also see comments on [this commit](https://github.com/aces/cbrain/commit/13718d585c2a3345556fb79e55d7ce2977135c6a)

#### Version 5.1.2 Released 2019-06-07

The release includes new features and bug fixes.

New features:

- Boutiques descriptors can request their shell to
  be something other than 'bash'
- Boutiques tasks that work on a multiple input files
  now properly record provenance of their outputs
- Custom filters now support multi-select lists for
  many attributes
- API requests will be refused if they suddenly come from
  a different origin
- DataProviders have two new fields to support Datalad servers
- The swagger spec defines page and per_page query parameters
- Tasks that no longer have a workdir are deleted by the portal
- API users can group together new tasks under the same batch_id
- The server list will show red indicators if a Bourreau is
  running in an environment different from the portal (e.g.
  production vs development)
- The admin console now has a 'last' command just like in UNIX

Bugs fixed:

- We use Process.setproctitle() instead of writing to $0
- The custom 'confirm' dialog was changed to a standard Rails one
- Project list show the creators properly
- Project buttons allow deletion
- Roaming users will see their IP address update properly
- Extracting files from FileCollections now guess their types
  and will not proceed if the DP is not writable
- The system won't attempt to send emails if it's not configured
  for email anyway
- Very rare duplications of SyncStatus objects, caused by race
  conditions, are detected and fixed at boot time
- Miscellaneous other small fixes

#### Version 5.1.1 Released 2019-03-13

This is mostly a bugfix release. There is one major new
feature: the Boutiques integrator now has hooks to
allow a superclass to override its subclasses behavior (!),
which is useful when coding special integrators. The
current use case is the BidsAppHandler class in the
cbrain-plugins-neuro package.

Bugs fixed:

- Spawned subprocesses woudl no longer log exceptions and just
  disappear; handler code was still using the old Mysql::Error
  instead of Mysql2::Error
- Bourreaux now set the env variable OBJC_DISABLE_INITIALIZE_FORK_SAFETY=yes
  this is needed on latest maxOS versions
- User messages are properly appended to 'read' messages
- Tool forms are adjusted slightly
- The boot process now lists each task descriptor has it is being integrated
- Some better docs

#### Version 5.1.0 Released 2018-11-16

It is the age of wisdom, it is the age of foolishness.

General changes:

- The old S3DataProvider code has been revamped
  to use the new Amazon SDK
- A new S3FlatDataProvider was added; it can browse the
  objects in a bucket and register them as files
- Parallelized tasks are better are recovery
- Restarting PostProcessing on tasks now works again
- The show_table helpers can pass around the FormBuilder form handler
- Several show_tables can be linked into a single form
- Links to the ExceptionLog objects now work
- Plugins and Boutiques tasks provide proper revision info
- The Tool show page use the show table helpers
- The ToolConfig show page is used to create and edit them
- Better error messages when a Boutiques descriptor fails to integrate
- New rspec test set for the ParamsErrors class
- Improved Travis CI integration scripts

Some changes are related to the console environment:

- New helpers: `online`, `offline`, `tv`
- New generic scopes: `utoday`, `ctodat`, `uweek`, `cweek`

Several changes are related to the API:

- The Swagger API spec has been updated; it is still a Swagger 2.0 spec
- The controller code has all been adjusted to match it
- A curl-based testing framework was added to test API calls
- A Ruby-based testing framework was added too
- Both testing frameworks use the same set of 'req' files for testing
- A Ruby gem, `CbrainClient`, was created out of the swagger spec
- The gem is at https://github.com/aces/cbrain-client-gem

#### Version 5.0.2 Released 2018-03-09

Several bug fixes (boring!) and enhancements (yeah!)

- Singularity support fixes (build instead of pull, exec instead of run)
- jQuery fixes
- API is now single-token based (Bearer token)
- API improvements (limits, simpler filters)
- Switch project clears the persistent list
- Containers mount local DPs
- Plugins can provide arbitrary ruby code in their lib/
- A task's work directory can be saved for inspection
- Launching tasks checks accessibility of inputs
- Lots of tiny internal bugs fixes

#### Version 5.0.1 Released 2018-01-03 (Happy Birthday)

This release contains a few bug fixes identified while running 5.0.0
in production. It also includes one new feature, a ScratchDataProvider
class that programmers can use to store data files in a temporary
area (the app's cache space) while still benefiting from all the APIs
provided by the data provider framework.

#### Version 5.0.0 Released 2017-12-12

This is the first release based on Rails 5.0.

- No major new features compared to 4.7.1.
- User interface is similar, but some buttons have a different appearance.
- Several internal bug fixes were applied.
- The application follows more closely the Rails 5 conventions.
- The web server is now 'puma' instead of 'thin'.

#### Version 4.7.1 Released 2017-12-12

This is the last release in the 4.7 series, which was built on Rails 3.2.
The next release will be the 5.0 series based Rails 5.0.

- Some big fixes and improvements in container support
- Better supprot for Singularity
- Added support for ScirSlurm and ScirCobalt

#### Version 4.7.0 Released 2017-04-24

- Signups index page improved.
- Container support made more modular: Docker and Singularity.
- Container support for local images as userfiles.
- Pretty view helpers in Rails console.
- New console helpers 'trans' and 'acttasks'.
- Feedbacks forms/model removed.
- Support for optional Network Operation Center view page.
- Swagger authentication getting closer to operational.
- General swagger improvements.

#### Version 4.6.1 Released 2016-12-19

- A much more complete version of the Swagger API spec (but not final).
- Support for version 0.4 of the Boutiques descriptors.
- Misc bug fixes.

#### Version 4.6.0 Released 2016-11-21

- Build-in support for Travis Continuous Integration.
- User registration form.
- Preliminary Swagger API support (incomplete!).
- New credits page.
- Browsing files within a collection now allows downloading them.
- Boutique support for containers.
- Many UI improvements.
- Many internal bug fixes and performance enhancements.

#### Version 4.5.0 Released 2016-08-18

- Preliminary (alpha) support for Amazon clusters.
- Added AccessProfiles, an administrative feature.
- More Boutique support; test of boutique-generated code.
- Refactoring: DataProvider classes and transactions.
- Drop historical support for SVN IDs for internal provenance tracking.
- Bourreau-side tests framework fixed; tests forthcoming.
- Removed overlays for creating new resources.
- Better console built-in help.
- New CbrainFileList base file type.
- Support for flatfile-based revision tracking in plugins.
- Removed support for Mozilla Persona.

#### Version 4.4.0 Released 2016-05-31

- SCIR class for LSF batch manager.
- New subtasking mechanism, improved.
- Fixed filter links in report maker.
- Fixed and extend _qc_panel.
- Added an interface for tasks to create a progress bar showing their status.
- Fixed bug in UI (example: avoid auto-focusing tag selection).
- Fixed upload with auto-extraction.
- Dashboard and search available for all users.
- Improved boutique support.
- Improved csv format of userfiles index page.

#### Version 4.3.0 Released 2016-03-16

- There is a new tools launching interface.
- Tools can have tags set up by the administrator.
- The new launch interface allow filtering tools by these tags.
- Tasks running on a cluster's node now have a framework
  that allows them to tell CBRAIN to launch new tasks.
- Console utilities for the administrator.
- Bug fixes, small improvements in performance, etc.

#### Version 4.2.1 Released 2015-10-30

Hot bug fixes in the previous release, related to bad files on
the Bourreau Rails app side.

#### Version 4.2.0 Released 2015-10-30

Bug fixes and enhancements.

- Scope system refactored completely
- 'Boutique' system integration
- Docker support for ClusterTasks.

#### Version 4.1.0 Released 2015-08-13

Several bug fixes, enhancements, and new features. The layouts of
many tables have been cleaned, using new APIs (thank you Remi).

As of now, new development will occur in a branch called "dev".
The branch named "master" will always point to the latest release
including special patches. When a new release is ready in "dev",
we will merg it to "master" and tag it there.

#### Version 4.0.1 Released 2015-05-19

This release contains several bug fixes and tidying of loose ends
from the 4.0.0 public release. Most of the fixes are descrived
under the milestone "Post Public Release" in the GitHub issue tracker.

#### Version 4.0.0 Released 2015-03-27

This is the first publicly released version of the CBRAIN platform.
There are still significant rough edges in the code and the
installation procedure, and the Wiki documentation is about 80%
complete.

In the near future, we plan to:

- Move our code issues from our internal Redmine server to GitHub's issue tracker.
- Implement significant performance improvements that have revealed themselves necessary in production.
- Finish the documentation.

Currently available plugins packages are:

- [cbrain-plugins-neuro](https://github.com/aces/cbrain-plugins-neuro)
- [cbrain-plugins-fmri-psom](https://github.com/aces/cbrain-plugins-fmri-psom)

