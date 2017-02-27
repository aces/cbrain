
# Continuous integration with [Travis CI](https://travis-ci.org/)

This directory contain all the support files and scripts for testing CBRAIN within a Docker container running on a VM provided by Travis CI.

The process works in two steps.

* a docker container is prepared, once, and published on DockerHub or kept locally. This step is performed by the script `Travis/build_container.sh`.
* when Travis detects a push on a CBRAIN repo that it tracks, it will invoke (through the `.travis.yml` file a the top of CBRAIN's repo) the script `Travis/travis_ci.sh`.

This script `travis_ci.sh` will launch the container prepared in the first step.

The container will run `bootstrap.sh`, which is the main docker entry point, and as root it performs these two operations:

* first it simply starts the MySQL DB server
* second it invokes, as user 'cbrain', the script `cb_run_tests.sh` which performs the setup necessary to run the test suites.

## Trying it out locally

The entire process can be tried locally without setting up all the Travis CI configuration, as long as Docker and Docker Compose are available.

```bash
    cd Travis
    bash build_container.sh -b hello/bye    # "hello/bye" can be any container name of your choice
    cd ..
    env CBRAIN_CI_IMAGE_NAME=hello/bye bash Travis/travis_ci.sh  # the container name can be given in argument too
```

