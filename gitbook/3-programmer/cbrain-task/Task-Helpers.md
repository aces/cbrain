This document contains several lists of helper methods
for writing CBRAIN tasks, with some notes.
Full descriptions of the methods with examples can be
obtained by generating the code documentation, as explained
at the begining of the [Programmer Guides](../Programmer-Guides.html).

Methods listed in the following tables use this convention:

* Class method names are preceded by `::`
* Instance method names are preceded by `#`

## CbrainTask Model Helpers

These methods are usually defined in the file `models/cbrain_task.rb`
and are thus available on both the Portal and Bourreau side of a CBRAIN
installation.

#### Methods returning IDs, names, and combined identifiers

| Method Name           | Notes              |
|-----------------------|--------------------|
| ::pretty_type         |                    |
| #name                 |                    |
| #name_and_bourreau    |                    |
| #fullname             |                    |
| #pretty_name          |                    |
| ::pretty_name         |                    |
| #bid_tid              |                    |
| #bname_tid            |                    |
| #bname_tid_dashed     |                    |
| #tname_tid            |                    |
| #run_number           |                    |
| #run_id               |                    |

#### Methods returning properties of a task

| Method Name           | Notes              |
|-----------------------|--------------------|
| ::tool                | Not an attribute of a CbrainTask. |
| #tool                 |                    |
| #full_cluster_workdir |                    |
| #cluster_shared_dir   |                    |
| #short_description    |                    |
| #archived_status      |                    |

#### Methods related to creating dependencies with other tasks

| Method Name                               | Notes              |
|-------------------------------------------|--------------------|
| #share_workdir_with                       |                    |
| #add_prerequisites                        |                    |
| #remove_prerequisites                     |                    |
| #add_prerequisites_for_setup              |                    |
| #add_prerequisites_for_post_processing    |                    |
| #remove_prerequisites_for_setup           |                    |
| #remove_prerequisites_for_post_processing |                    |

#### Additional data provenance methods

| Method Name                        | Notes              |
|------------------------------------|--------------------|
| #addlog                            |                    |
| #addlog_exception                  |                    |
| #addlog_current_resource_revision  |                    |

#### Callbacks and other custom controls

| Method Name               | Notes              |
|---------------------------|--------------------|
| ::after_status_transition | Can be used as a directive in a class |



## PortalTask Model Helpers

These methods are only available when tasks are instanciated on a
BrainPortal rails application. They are usually defined in the file
`models/portal_task.rb` (which inherit from `models/cbrain_task.rb`).
A task programmer will therefore only invoke them when writing the
Ruby files located under the `portal` subdirectory of the task's codebase.


#### Main Portal API methods (not really helpers)

These methods are usually redefined in subclasses to implement the
proper portal functionality of a CbrainTask.

| Method Name                          | Notes              |
|--------------------------------------|--------------------|
| ::properties                         |                    |
| ::default_launch_args                |                    |
| ::pretty_params_names                |                    |
| #before_form                         |                    |
| #refresh_form                        |                    |
| #after_form                          |                    |
| #final_task_list                     |                    |
| #after_final_task_list_saved         |                    |
| #untouchable_params_attributes       |                    |
| #unpresetable_params_attributes      |                    |

#### Other methods

| Method Name           | Notes              |
|-----------------------|--------------------|
| #capture_job_out_err  | Actively contacts the Bourreau side |
| ::public_path         | For static assets |
| #public_path          | For static assets |

## ClusterTask Model Helper

These methods are only available when tasks are instanciated on a
Bourreau rails applciation. They are usually defined in the file
`models/portal_task.rb` (which inherit from `models/cbrain_task.rb`).
A task programmer will therefore only invoke them when writing the
Ruby files located under the `bourreau` subdirectory of the task's codebase.

#### Main Bourreau API methods (not really helpers)

These methods are usually redefined in subclasses to implement the
proper bourreau functionality of a CbrainTask.

| Method Name                             | Notes              |
|-----------------------------------------|--------------------|
| #setup                                  |                    |
| #cluster_commands                       |                    |
| #save_results                           |                    |
| #job_walltime_estimate                  |                    |
| #recover_from_setup_failure             |                    |
| #recover_from_cluster_failure           |                    |
| #recover_from_post_processing_failure   |                    |
| #restart_at_setup                       |                    |
| #restart_at_cluster                     |                    |
| #restart_at_post_processing             |                    |

#### Utility methods for working in the work directory

| Method Name                 | Notes              |
|-----------------------------|--------------------|
| #safe_mkdir                 |                    |
| #safe_symlink               |                    |
| #safe_userfile_find_or_new  |                    |
| #path_is_in_workdir?        |                    |
| #tool_config_system         |                    |

#### Additional data provenance methods

| Method Name                              | Notes              |
|------------------------------------------|--------------------|
| #addlog_to_userfiles_processed           |                    |
| #addlog_to_userfiles_created             |                    |
| #addlog_to_userfiles_these_created_these |                    |


#### Utility methods for generating output names

| Method Name                            | Notes              |
|----------------------------------------|--------------------|
| #output_renaming_standard_keywords     |                    |
| #output_renaming_add_numbered_keywords |                    |

#### Access to task's captured outputs

| Method Name              | Notes              |
|--------------------------|--------------------|
| #stdout_cluster_filename |                    |
| #stderr_cluster_filename |                    |

#### Archiving methods

| Method Name                             | Notes              |
|-----------------------------------------|--------------------|
| #archive_work_directory                 |                    |
| #unarchive_work_directory               |                    |
| #archive_work_directory_to_userfile     |                    |
| #unarchive_work_directory_from_userfile |                    |

## Task View Helpers

These methods are helpers for writing the task's interface. They
are usually invoked from within the Rails partials and template files
located in the `views` subdirectory of the task's codebase.

| Method Name                             | Notes              |
|-----------------------------------------|--------------------|
| #task_partial                           | For tasks with complex interfaces stored in multiple files |
| #output_renaming_fieldset               | Utility, to use in conjunction with `#output_renaming_add_numbered_keywords` on the Bourreau side |



