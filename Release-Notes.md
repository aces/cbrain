
## CBRAIN/NeuroHub Release Notes

#### Version 6.2.0 Released 2022-01-28

(After eleven months, the `git diff` output is over 12,000 lines long!)

Major features:

* A new Boutiques integrator was implemented. This new framework
  is modular and customizable, and much easier to maintain.
  from the developer's perspective. Some technical documentation
  is in this [presentation](https://prioux.github.io/new-boutiques-presentation/#/title).
* The new Bouiques integrator comes with four new modules that sysadmins
  can configure withing each Boutiques descriptor:
  * BoutiquesFileNameMatcher
  * BoutiquesFileTypeVerifier
  * BoutiquesOutputFileTypeSetter
  * BoutiquesPostProcessingCleaner
* Users can link their account to a Globus identity and
  authenticate with Globus from that point on.
* A new DataProvider types has been added: SingBindMountDataProvider.
  It access files in squashfs or ext3 overlays using the singularity
  bindmount feature.
* The NeuroHub interface now shows the user's own private project.
* A new 'stream' action has been added to the userfile model,
  allowing seemless path-based access to file contents.
* Sysadmins have access to a set of new rake tasks to extract old record
  from the resource_usage table, and get them saved into YAML files.
  Replacement monthly summary records can then be reinserted in the database
  so that the usage tracking for all resources stay accurate.

Other enhancements:

* New NOC status and statistics pages: users over time, tools usage
  over time, tasks CPU time over time.
* The main login page has a public list of configured tools and datasets.
* The data structure that maintains statistics about the portal
  requests has been simplified.
* S3 data providers can be configued with distinct regions and endpoints.
* A new class of users, AutomatedUser, is available for automatic systems.
* Admins can configure overlays for Singularity-launched tools
  by provding the overlays as userfiles.
* A new tool, SimpleFileExtractor, is provided with the distribution.

#### Version 6.1.0 Released 2021-02-26

This release contains several new features and bug fixes.

* The Continuous Integration system has been switched from
  Travis CI to GitHub actions. The control script for the
  running the test suite is under .github/workflows/cbrain_ci.yaml
* The remote script that starts a Bourreau has been switched
  from a ruby script to a simpler bash script; the bash script
  is used in the most common situation of launching a Bourreau,
  and the old ruby script is still invoked in other rarer modes
  of operation.
* Browsing data providers now support 'local subpaths'. This
  is enabled only on some select DataProvider subclasses.
  This mechanism is meant for read-only data providers only,
  and can only be accessed by administrators. Warning: registering
  files that are subsets of other registered files can have
  unpredictable consequences.
* A new specialized controller for LORIS hooks has been added.
  This is used by automated operations from LORIS systems.
* NeuroHub users can send direct messages to each other. This
  feature is not accessible on the CBRAIN side yet, but users
  can switch from one interface to the other.
* NeuroHub users can destroy their old project.
* Different internal mailer configurations allow two sets of
  email messages to be set to users depending on whether they
  interact with the CBRAIN side or the NeuroHub side (for
  registration, password recovery etc).
* CBRAIN administrators can now explicitely indicate that
  a tool is known not to modify its input files, allowing
  users to launch such tools on files on which they only
  have read access. In the past, the interface would refuse
  to launch the tools because it didn't know if that would
  modify the files.
* CBRAIN admins can configure tasks that are containerized
  in Singularity to mount specific file overlays in the container
  (for example, for fixed datasets).
* CBRAIN admins can specify special Singularity run-time options
  for tasks that are containerized with Singularity.
* The task launching system will autodetect if a CBRAIN file
  is located on a data provider that stores files in Singularity
  overlays and mount the overlays automatically if the task
  is also run with Singularity.
* NeuroHub users can generate new API tokens just like on the
  CBRAIN side.
* Internal version tracking is performed by `git describe`
  instead of the old ruby code that basically did the same thing.
* The Boutiques integrator supports a new special custom
  option allowing a task to save back its input automatically.

#### Version 6.0.0 Released 2020-08-19

More than 8 months have passed since the previous release, 5.3.0!

This release introduces the new GUI interface called `NeuroHub`.
The original CBRAIN interface is still all there; NeuroHub
is an additional set of pages providing a new look and feel, and
new capabilities. NeuroHub is still rather restricted in what
it can do, but users can easily switch back and forth between
the two interfaces at the push of a button (located at the top
and left on each interface).

New CBRAIN features: (some of these apply to NeuroHub too)

* Projects can be tagged as 'un-assignable", so that a member
  of the project cannot assign userfiles or tasks or other resources
  to it (except for the project's creator). This is mostly
  useful for projects that represent fixed datasets that are
  meant to be used but not extended further.
* CBRAIN (and NeuroHub) now creates a single pair of SSH keys
  (one private, one public) for each user that the system can
  use to access external resources. The private key is never
  made visible. Right now this is mostly useful for the new
  UserkeyFlatDirSshDataProvider class in NeuroHub.
* These keys (full pair) can be pushed to a Bourreau so that
  the CBRAIN code running there can connect as the user. Users
  have control over which bourreau to push their key pair to.
* CBRAIN can generate a new API token and show it to the user
  in their 'my account' page.
* When a user accepts an invitation to join a project, the
  person who made the invitation is notified.
* When an admin reviews a signup request, they can tell
  if the request was made using the CBRAIN or the NeuroHub
  signup page.
* Users can see how many active sessions they have (including
  API sessions), and from what IP they connected.
* Admins can set a user's default data provider when creating
  their account.

NeuroHub exclusive features:

* If a user enters their ORCID ID in their profile, they
  can log in using the ORCID authentication platform.
* Projects are limited to "Work" projects; the other special
  projects that CBRAIN supplies by default are hidden.
* Projects can have special members designated as 'editors'.
* Project editors have much the same powers as the project's creator.
* A project's creator can assign a license to it; members will
  have to agree to the license before they can access it.
* Projects can be configured as 'public'. Things assigned to public
  projects can be accessed by any user.
* User can create their own Data Providers. This is limited right
  now to DPs of type 'UserkeyFlatDirSshDataProvider'. The provider
  side will be accessed using the personal SSH key of the user
  who created the DP. Mostly useful for power users who want to
  access remote filesystems.
* Specialized API hooks for LORIS integrations. Right now, only
  one such hook is implemented, `file_list_maker`.

Other:

* Much code refactoring (e.g. FileInfo class, BrowseProviderFileCaching,
  SshDataProviderBase...).
* Selection boxes are shown with the chosen.jquery.js framework.
* DP consistency checkers improved.

#### Version 5.3.0 Released 2019-12-10

New features:

- From a Task's information page, a user can now access a "Publish to Zenodo"
  page. The task's output and runtime information will be published to
  Zenodo. Caveat: pushing data is done synchronously, which blocks the
  browser (TODO, as pushing as a forked process messes up the libcurl library)
- The Network Operation Center now provides weekly, monthly and yearly reports
- Userfile resource usage tracking: whenever files are added, deleted or change size,
  persistent records are made about the change
- Task resource usage tracking: whenever tasks reach a final state, persistent records
  are made. These include the status of the tasks, but also their accumulated CPU
  and wall times
- Administrators can configure 'epilogue' sections of the tool configs, to match
  the existing prologue sections. This allow the admin to surround the running
  script with e.g. `sg newgroup bash <<TOKEN` (in the prologue) and `TOKEN` (in
  the epilogue), making sure the script runs with a particular effective GID.
- The QC panels for userfiles have a new layout; also users can toggle between
  one panel or two
- The S3FlatDataProvider class now allows confiuring a S3 provider that starts
  with a prefixed path (e.g. "/a/b/c", and all the files are under that)
- Users now have an 'affiliation' field, with a controled set of values for it
- Userfile custom viewers can return an informative error message informing the
  framework why they aren't available for a particular file
- New built-in viewers for Singularity image files, json files, xml files
- The Diagnostics tool has options for generating busy loops (system and/or user)

Bug fixes:

- Many many small ones.

#### Version 5.2.0 Released 2019-09-13

We added a Code Of Conduct file to the GitHub repo.

New features:

- The [CARMIN API](https://github.com/CARMIN-org/CARMIN-API) has been implemented
  pretty much completely, except for some limitations (users need to find externally
  the ID of CARMIN files in order to prepare the arguments for CBRAIN tasks)
- A new DataProvider that can connect to SquashFS files through Singularity
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

