
# CBRAIN API Testing Frameworks: REQ files

This directory contains a set of small text files,
called __req__ files, which describe simple API testing calls.

The files are read by testing frameworks or scripts located one
directory above.

The names and structure of all directories and subdirectories are
arbitrary. The frameworks will look for any files that end with
the three letters "req" and the content of the file will be parsed
to generate a test. The name of the test will be whatever relative
path leads to the file.

```
some/path/to/req      # Test name: 'some/path/to'
some/path/to/1.req    # Test name: 'some/path/to/1'
groups/create/req     # Test name: 'groups/create'
groups/create.req     # Test name: 'groups/create' (also)
```

Alongside each __req__ file, a set of other optional files can
be found by replacing the "req" part with some others strings:

Basename      | Description
------------- | ----------------------------------------------
abc.req       | main req file
abc.in.json   | input in json format, for PUT, POST, PATCH etc
abc.in.rb     | input in rb format, for CbrainClient tests
abc.out       | description of expected output
abc.in.data   | raw content (rarely used)
abc.in.form   | curl description of form data

## Testing order of the __req__ files

The testing frameworks are expected to run their tests in a randomized
order; however, given that some tests can depend on others, a
convention has been established to force some tests to happen before
others. The convention is simply that all tests contained
**within the very same subdirectory** will all be run in alphabetical order
within that directory, and back to back too (no tests from elsewhere
in the directory tree will be inserted in between).

## Format of __req__ file

The __req__ file contains a single line with pieces of information
separated by spaces; the first two are mandatory, the rest is optional

```
GET /userfile/15?NTOK application/json ControlKeyword
```

The components are, in order:

- The HTTP verb, one of GET, POST, PUT etc
- A relatve path; the strings NTOK, ATOK and DTOK are special (see below)
- The Content-Type of the request (curl only, optional, default application/json)
- Special control keywords specific to frameworks (rarely used)

If the path contains NTOK or ATOK or DTOK, the curl testing framework will
replace them with a proper specification for the CBRAIN API token for
(respectively) a **normal user**, an **admin user** and a **delete user**.
These correspond to hardcoded credentials established during the seeding
of the test database.

The Ruby testing framework will use this information to figure out
the name of the class and method to invoke, and with which client
credentials. In the example above, it will invoke:

```ruby
CbrainClient::UserfilesApi.new(normal_client).userfiles_id_get(15)
```

## Format of the __in.json__

Simply raw json text. Example:

```json
{
  "group": {
    "name": "yippy"
  }
}
```

## Format of the __out__ file

If not present, frameworks assume that the request must produce
a "200" response code and no output needs to be checked.

Otherwise, it has this format:

```
201 application/json remove_regex_1 remove_regex2
{"some":"content"}
```

All text starting at line 2 contain expected content; this is optional.

The first line is special an contains, in order:

- An expected HTTP return code (here 201)
- An expected content-type for the response (optional, default application/json)
- An options series of regular expressions; all matches will be **removed** from both
  the API response and the provided expected content that starts on line 2

Aside from the regex described above, test frameworks are encouraged
to hardcode a few removal operations before comparing outputs (gotten
vs expected):

- Remove all white spaces
- Remove all timestamps that match things like "2018-11-03T23:04:07.000Z"
- Remove "id":ddd when the action is a POST
- Transform all :true and :false into :"true" and :"false" (note the double quotes)

These transformations are implemented in the curl testing framework
as well as the Ruby CbrainClient testing framework.

## Format of the __in.rb__ file

The content of this file will be eval() in Ruby within the scope
of a **ParsedReq** object describing the current test. It should return
an array of things that will be passed, in order, to the CbrainClient
method that we are trying to invoke. For example, it could
contain simply

```ruby
  [ "a", 2 ]
```

and then the framework would invoke the method **some_test_method** as

```ruby
CbrainClient::SomethingApi.new(client).some_test_method("a",2)
```

A set of helper methods exist in the **ParsedReq** class to allow a test
designer to reload any parts of a __in.json__ file that exist in
the same test. This provides a way not to duplicate test data between
frameworks: a change in __in.json__ will propagate to what is constructed
in the __in.rb__ file.

### Author

Pierre Rioux, CBRAIN project, November 2018

