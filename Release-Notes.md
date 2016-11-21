## CBRAIN Release Notes

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

