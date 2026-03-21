
![Continuous Integration](https://github.com/aces/cbrain/workflows/cbrain_ci/badge.svg)

# CBRAIN

CBRAIN is a web-based platform that helps researchers work with large and distributed datasets. It handles things like user access, data transfer, caching, and provenance, and also connects with high-performance computing (HPC) and cloud resources to run heavy processing tasks.


## NeuroHub Portal

NeuroHub is an alternative interface to CBRAIN. It includes some features that are not available in CBRAIN yet, but at the same time, it doesn’t have all of CBRAIN’s functionality since it is still relatively new.

Both CBRAIN and NeuroHub use the same authentication and database system, so users can switch between them easily.


## Architecture Overview

CBRAIN (along with NeuroHub) is built using two Ruby on Rails applications:

### BrainPortal

BrainPortal is the frontend of CBRAIN. It provides a web interface where users can:

* Upload, tag, and search their data
* Run compute-intensive jobs on remote HPC systems
* Access files stored on different remote systems


### Bourreau

Bourreau acts as the backend of CBRAIN and is not directly used by end users.

It communicates with BrainPortal using XML and works as a bridge between user requests and the HPC systems.

Its responsibilities include:

* Receiving job requests
* Preparing the required environment
* Running tasks on HPC systems
* Sending results and generated files back to BrainPortal
* Providing updates on running jobs


## Possible Improvement: Python CLI

A Python-based command line interface (CLI) could be a useful addition to CBRAIN.

With a CLI, users could:

* Upload and download data from the terminal
* Submit and monitor jobs
* Automate workflows without using the web interface

This would especially help advanced users who prefer scripting and automation.


## For more information

CBRAIN is extensively documented in its [Wiki](https://github.com/aces/cbrain/wiki).

