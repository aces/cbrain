## CBRAIN Release Notes

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

