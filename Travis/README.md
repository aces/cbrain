
# Continuous integration with [Travis CI](https://travis-ci.org/)

This directory contain all the support files and scripts for testing CBRAIN within a Docker container running on a VM provided by Travis CI.

The process works in two steps.

* a docker container is prepared, once, and published on DockerHub or kept locally.
* when Travis detects a push on a CBRAIN repo that it tracks it will invoke (through the `.travis.yml` file a the top of CBRAIN's repo) the script `Travis/travis_ci.sh`

This last script with launch the container prepared in the first step, composed with a MariaDB container, and run the CBRAIN test suite with `rspec`.

## Trying it out locally

The entire process can be tried locally without setting up all the Travis CI configuration, as long as Docker and Docker Compose are available.

```bash
    cd Travis
    bash build.sh -b hello/bye    # "hello/bye" can be any container name of your choice
    cd ..
    env CBRAIN_CI_IMAGE_NAME=hello/bye bash Travis/travis_ci.sh  # the container name can be given in argument too
```

