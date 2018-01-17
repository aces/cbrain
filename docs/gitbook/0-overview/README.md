CBRAIN has several important capabilities:

* Files may be be stored anywhere: on local servers or on remote servers.
* Files are moved automatically and upon demand (e.g. by user or a
  task), without interfering with platform components and without
  the user having to worry too much about their actual location.
* Tasks can be launched at any scale: on local servers or on powerful
  compute clusters. CBRAIN supports clusters running Sun Grid Engine
  (SGE), MOAB, Torque/PBS, or simple UNIX processes, transparently.
  Other adapters are easy to implement.
* Files can be displayed or accessed on the web interface according
  to their own internal representation. For example a JPEG file can
  be viewed, or an MRI file can be parsed slice-by-slice on the web
  interface.
* Files and tasks are deployed as plugins, so a CBRAIN administrator
  can write his own or simply import them from other developers.

## Where does it come from?

The [**CBRAIN service**](https://portal.cbrain.mcgill.ca) was originally conceived
through a [CANARIE](http://www.canarie.ca)
grant awarded to [Professor Alan C. Evans](http://mcin-cnim.ca/people/alans-cv/), at
[McGill University](http://www.mcgill.ca). The resulting internal
code platform was meant
to provide easy access to complex neuroimaging computational tools, for
clinicians or neuroscience researchers with limited IT resources. Despite
the name, the framework is designed to be general, and can accommodate any
data and task for any application. This GIT repository contains the
generic core of the framework, _which is not specific to any field of science_.

## Who should use CBRAIN?

Any research group that depends on medium to large-scale computational data
analysis, can benefit from CBRAIN's data and task management back engine.
CBRAIN provides tools for archiving raw and processed data files, viewing them,
and processing then in batch. For example, an astronomy researcher's lab could deploy
CBRAIN and configure its data servers for storage of its instrument's acquisitions,
and to launch its in-house data processing/analysis software on some preconfigured
supercomputer cluster.

## Citing CBRAIN

If you publish results from deploying a CBRAIN instance, please cite the following
reference:

**Sherif T, Rioux P, Rousseau M-E, Kassis N, Beck N, Adalat R, Das S, Glatard T and Evans AC (2014)**   
_CBRAIN: a web-based, distributed computing platform for collaborative neuroimaging research._  
[Front. Neuroinform. 8:54. doi: 10.3389/fninf.2014.00054](http://journal.frontiersin.org/article/10.3389/fninf.2014.00054/abstract)

## Need help ?

This software was written and is maintained by programmers at the
[McGill Centre for Integrative Neuroscience](http://mcin-cnim.ca) (MCIN),
at the [Montreal Neurological Institute](http://www.mcgill.ca/neuro/), in
Montréal, Québec, Canada.

The initial public release was done in March, 2015. We encourage
everyone to use GitHub's issue tracker to report any problem or
make suggestions for future features. For all other inquiries, please
write to cbrain-support.mni@mcgill.ca
