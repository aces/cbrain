
## CBRAIN development and maintenance scripts

This directory contains a few useful scripts for developers.

#### make_local_doc.sh

This program will run two `rake` tasks to generate the code documentation
from the CBRAIN sources, one for each of the two Rails applications that
are part of the package (BrainPortal and Bourreau). You can then open
the plain HTML files by pointing your browser to

    your_CBRAIN_work_path/BrainPortal/doc/brainportal/index.html

and

    your_CBRAIN_work_path/Bourreau/doc/bourreau/index.html

(the script will give your the full URLs after it is done executing)

The script takes no arguments.

#### make_all_rev_csv.sh

This program will generate one (or more) CSV files containing the
revision commit IDs of the last commit that affected each file in CBRAIN.
These CSV files are used by CBRAIN as a fallback mechanism when the application
is not deployed using the GIT program. In that case, in order to track
precisely the revision number of each file, CBRAIN will extract (and cache)
the revision info found in these files.

The main file for the CBRAIN platform is in the root of the CBRAIN project
and is called `cbrain_file_revisions.csv`. Additionally, each CBRAIN plugins
package can have their own file (named the same way) in their own top-level
directory.

This program will regenerate all these files by calling the script
`gen_local_rev_csv.sh` in the root of the CBRAIN project, and calling
it again once in each of the plugin packages directories.

This script is usually invoked just before releasing a new version
of CBRAIN, or of one of its plugins, in order to prepare the file list
of revision information that gets committed with the release.

The script takes no arguments.

#### gen_local_rev_csv.sh

As explained in the paragraph above, this script is invoked by `make_all_rev_csv.sh`.
It can be used separately to generate a single `cbrain_file_revisions.csv` file,
either in the root of the CBRAIN platform or within one of the plugin packages.

The script takes no arguments.

