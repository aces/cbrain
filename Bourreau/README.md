= CBRAIN Project : Bourreau

Welcome the CBRAIN Bourreau application!

== About Bourreau

Bourreau is the backend of the CBRAIN architecture. It is a
Rails application that is not meant to serve the user directly. It
interacts with the CBRAIN Brainportal application using XML, acting as
an intermediary between user requests through BrainPortal and the cluster
management software running on High-Performance Computing sites. A Bourreau
receives requests to launch a processing task, sets up the require working
directories, runs the process and then sends information about any newly
created files back to BrainPortal. A Bourreau can also be queried about
the jobs that are currently running on the HPC where it resides.

== Design Philosophy

Bourreau has been built using Ruby on Rails. {Ruby}[http://www.ruby-lang.org/en/]
is a dynamic, object oriented language. {Rails}[http://rubyonrails.org/] is a web-development
framework based on Ruby.

=== Some key models in the system include:

*User*:: Represents an actual user of the system. 
*Userfile*:: Models a user's files as entries in the database. 
*DataProvider*:: Represents an external provider for the contents of the userfiles.
*CbrainTask*:: Represents a task being run on a cluster, and its evolving states. 
*ClusterTask*:: The subclass of CbrainTask used to modelize tasks on the Bourreau side.
*Bourreau*:: Represents a Bourreau.

