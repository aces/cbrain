Within CBRAIN, the model files for Userfiles and CbrainTasks are not stored in the traditional Rails location, the app/models directory. Instead, a 'plugin' structure has been designed where those Userfiles and CbrainTasks are stored. The advantage of this approach is that the main CBRAIN framework can be updated and maintained separately from these models.

## Specification of a plugin package

Within the CBRAIN code branch, the plugins are deployed in:

    /path/to/BrainPortal/cbrain_plugins

Two subdirectories located within that subdirectory contain the default distribution:

    /path/to/BrainPortal/cbrain_plugins/installed-plugins
    /path/to/BrainPortal/cbrain_plugins/cbrain-plugins-base

#### "installed-plugins"

The first of these subdirectories, 'installed-plugins', is an administrative 
subdirectory where plugins are 'installed' by *rake* tasks. 
Basically, its content is populated by a set of UNIX 
symbolic links with relative paths to the real files of the plugins. Usually, there
would be no reason for programmers or administrators to change anything there. It 
can usually be left alone.

#### "your-plugin-package-name" (e.g. "cbrain-plugins-base")

The second of these subdirectories, 'cbrain-plugins-base', is a complete example 
of a 'plugin package', and contains the default set of Userfiles and 
CbrainTasks that come with the default installation. A quick inspection of its
content show that a 'plugin package' contains two subdirectories, one for 
Userfiles and one for CbrainTasks:

    cbrain-plugins-base/userfiles
    cbrain-plugins-base/cbrain_task    # singular, for historical reasons :-(

Again, within each of these two subdirectories will be another level
of subdirectories, one per Userfiles (under userfiles/) and one per
CbrainTask (under cbraintask/).

This structure allows a scientific programmer to distribute, as a
complete 'plugin package', a full set of Userfiles and CbrainTask
that logically go together. As an example, assume a programmer wants
to add a plugin package for a set of neurology tools and userfiles. 
Assuming the package is on GitHub as "aces/cbrain-plugins-neuro", the
programmer can simply issue these commands:

```bash
    cd /path/to/BrainPortal/cbrain_plugins
    git clone https://github.com/aces/cbrain-plugins-neuro.git   # will create 'cbrain-plugins-neuro/' here
```
The rest of the installation steps are outside the scope of this document, but
suffice to say this simple `git clone` command has installed most of the files
cleanly and efficiently.

## Structure of a Userfile plugin

To write.


## Structure of a CbrainTask plugin

To write.

#### Rails Generator for CbrainTask

CBRAIN comes with a Rails generator to help programmers create new
CbrainTasks. A separate [document](cbrain-task/Rails-CbrainTask-Generator.html)
explains how to use it.

## Plugin package installation

    rake cbrain:plugins:install:all

            
              
**Note**: Original author of this document is Pierre Rioux