
# CBRAIN API Testing Frameworks

This directory contains several frameworks for testing the network API for CBRAIN:

- A testing script in perl which invokes curl(1) commands
- A Ruby class used by a rake task which invokes CbrainClient methods (from the gem 'cbrain_client')

Alongside these, a subdirectory called __req_files__ contains a set of short text
files that specify, in a framework-independent way, the tests to run.
More information about them can be found in the included [README.md](req_files/README.md) file.

Each of these require that a proper test environment be set up.

Given that that CBRAIN's __database.yml__ file properly defines a *test*
database, then it can be seeded properly with this rake task:

```bash
cd BrainPortal
rake db:seed:test:api
```



## Starting the server in the test environment

Before running any of the tests, a rails server needs to be started
within the *test* environment of the __database.yml__ file. There
are several ways of doing this, but the simplest is with:

```bash
cd BrainPortal
rails server puma -p 3000 -e test
```

You might want to perform a `tail -f log/test.log` in a separate
window to view the server's trace. If you prefer to launch the
server and monitor its logs all within the same window, then this
variation will work too:

```bash
cd BrainPortal
test -f tmp/pids/server.pid && kill $(cat tmp/pids/server.pid) ; rails server puma -p 3000 -e test -d ; sleep 5 ; tail -f log/test.log
```

This command allows you to hit *CTRL-C* and *up arrow* to restart
it as often as needed, when (for instance) modifying the CBRAIN
code base during test.

This will leave the server running in background (because of `-d`),
so consider killing it when you are done.



## Running the curl-based tests

The main entry point is the script __curl_req_tester.pl__ . Simply invoking it will
run all the tests:

```
perl curl_req_tester.pl       # standard verbose level of 1
perl curl_res_tester.pl -v0   # silent checks
perl curl_res_tester.pl -v4   # verbose level 4
perl curl_res_tester.pl users # select by substring match just a subset of all tests
perl curl_res_tester.pl groups/list # another more specific subset
```

More information about its usage statement can be obtained by running it with __--help__.
**Note that it will automatically run the rake seeding task by default!**



## Running the ruby CbrainClient tests

The rake task __cbrain:test:api:client__ will load the necessary Ruby classes
and starts running the tests:

Unlike the curl testing script described above,
**you must invoke the the seeding task explicitely before running the test task**.

```
rake db:seed:test:api ; rake cbrain:test:api:client # always seed first!
```

Choosing a verbose level and selecting specific tests is accomplished
the same way as for the curl testing script:

```
rake cbrain:test:api:client -v 2
rake cbrain:test:api:client groups/list
rake cbrain:test:api:client -v 4 groups/list
```

### Author

Pierre Rioux, CBRAIN project, November 2018

