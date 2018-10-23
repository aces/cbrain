#!/usr/bin/perl -w

##############################################################################
#
#                                 test_all.pl
#                           Pierre Rioux, Oct 201
#
# DESCRIPTION:
# Runs a set of test cases for the CBRAIN API
#
##############################################################################

##########################
# Initialization section #
##########################

require 5.00;
use strict;

# Default umask
umask 027;

# Program's name and version number.
my ($BASENAME) = ($0 =~ /([^\/]+)$/);
my $VERSION    = "1.0";

# Get login name.
my $USER=getpwuid($<) || getlogin || die "Can't find USER from environment!\n";

#########
# Usage #
#########

sub Usage { # private
    print <<USAGE;

This is $BASENAME $VERSION by Pierre Rioux

Usage: $BASENAME [-v[0-6]] [-h server] [-p port] [-s scheme] [-R] [test_substring]

Important: Make sure your RAILS_ENV is set to "test", and that your
rails configuration for it DOES point to a test database, because
its entire content will be WIPED!

Default server (-d) : "localhost"
Default port (-p)   : 3000
Default scheme (-s) : "http"

The "test_substring" argument can be used to filter out any part of the
relative paths to the "req" files under "curltests/", e.g. "normget"
or "users/normget" or "users" etc. This is not a regex or a pattern,
just a substring match.

The option -v controls the verbose level. The level can be set explicitely
with -v1, -v2, -v4 etc, or it can be increased by 1 with successive -v flags.

Verbose levels:
  -v0 : No output printed at all
  -v1 : (default) Shows a short summary of the tests being run
  -v2 : Shows the curl command and the curl return code
  -v3 : Shows the HTTP header of the response
  -v4 : Shows the HTTP content of the responses and curl's STDERR
  -v5 : When HTTP content differs from expected, shows them both

The option -R tells the script to NOT run the rake seeding command first.

USAGE
    exit 1;
}

##################################
# Global variables and constants #
##################################

my $VERBOSE = 1; # use -v0 to disable all messages
my $HOST    = "localhost";
my $PORT    = 3000;
my $SCHEME  = 'http';
my $TEST_SUBSTRING = "";
my $SEED_DB = 1; # -R sets this to false and then no rake task is run

# These tokens must match what will be seeded by the
# rake task 'db:seed:test:api'.
my $ADMIN_TOKEN  = "0123456789abcdef0123456789abcdef";
my $NORMAL_TOKEN = "0123456789abcdeffedcba9876543210";
my $DEL_TOKEN    = "0123456789abcdefffffffffffffffff";

# Record all test failures
my %FAILED_TESTS = (); # test_name => [ type, type, ... ] ; type any of CURL, CONTENT-TYPE, CONTENT, HTTPCODE

##############################
# Parse command-line options #
##############################

for (;@ARGV;) {
    # Add in the regex [] ALL single-character command-line options
    my ($opt,$arg) = ($ARGV[0] =~ /^-([vhpsR])(.*)$/);
    last if ! defined $opt;
    # Add in regex [] ONLY single-character options that
    # REQUIRE an argument, except for the '@' debug switch.
    if ($opt =~ /[hps]/ && $arg eq "") {
        if (@ARGV < 2) {
            print "Argument required for option \"$opt\".\n";
            exit 1;
        }
        shift;
        $arg=$ARGV[0];
    }
    $VERBOSE=(defined($arg) ? $arg : ($VERBOSE+1))     if $opt eq 'v';
    $HOST=$arg                                         if $opt eq 'h';
    $PORT=$arg                                         if $opt eq 'p';
    $SCHEME=$arg                                       if $opt eq 's';
    $SEED_DB=0                                         if $opt eq 'R';
    shift;
}

#################################
# Validate command-line options #
#################################

$TEST_SUBSTRING=shift if @ARGV;
&Usage if @ARGV != 0;

################
# Trap Signals #
################

sub SigCleanup { # private
    die "\nExiting: received signal \"" . $_[0] . "\".\n";
}
$SIG{'INT'}  = \&SigCleanup;
$SIG{'TERM'} = \&SigCleanup;
$SIG{'HUP'}  = \&SigCleanup;
$SIG{'QUIT'} = \&SigCleanup;
$SIG{'PIPE'} = \&SigCleanup;
$SIG{'ALRM'} = \&SigCleanup;

###############################
#   M A I N   P R O G R A M   #
###############################

# Just a quick check for a proper cwd
die "This program must be run in the BrainPortal/test_api directory.\n" unless -f "test_all.pl" && -d "curltests";

# Rails 'test'
die "This program must be run with the RAILS_ENV environment set to 'test'.\n" unless ($ENV{'RAILS_ENV'} || "") eq 'test';

# Initial banner
print <<HELLO if $VERBOSE > 0;
===============================================
API Tests Starting
===============================================

HELLO

# Init the RAILS_ENV=test DB
if ($SEED_DB) {
  print "Seeding DB with API test data...\n" if $VERBOSE > 0;
  my $ret = system "rake db:seed:test:api >/tmp/rake.$$.out 2>&1";
  if ($ret != 0) {
    print "\n";
    print "Cannot init test DB with API seed values:\n";
    print "Rake task 'db:seed:test:api' failed.\n";
    print "Captured output of rake task:\n";
    system "cat /tmp/rake.$$.out";
    unlink "/tmp/rake.$$.out";
    exit(2);
  }
  unlink "/tmp/rake.$$.out";
}

# Generate list of tests
my @list = qx( find curltests -type f -name '*req' -print );
chomp(@list);
print "\nFound ",scalar(@list)," CURL test files.\n" if $VERBOSE > 0;
print " => ",join("\n => ",@list),"\n"               if $VERBOSE > 2;

# Filter tests if a name was provided in args
if ($TEST_SUBSTRING) {
  @list = grep((index($_, $TEST_SUBSTRING) >= 0), @list);
  print "\nFiltered down to ",scalar(@list)," CURL test files.\n" if $VERBOSE > 1;
  print " => ",join("\n => ",@list),"\n"                          if $VERBOSE > 2;
}

# Shuffle the list; really dumb shuffle and oh do I miss Ruby's .shuffle().
for (my $i=0;$i<@list;$i++) {
  my $j = int(rand(@list));
  my $vi = $list[$i];
  my $vj = $list[$j];
  $list[$i] = $vj;
  $list[$j] = $vi;
}
print "\nReordered list.\n"            if $VERBOSE > 1;
print " => ",join("\n => ",@list),"\n" if $VERBOSE > 2;

# Process each of them
my $captH = "/tmp/capt-H.$$.curl";  # capture response header
my $captC = "/tmp/capt-C.$$.curl";  # capture response content
my $captE = "/tmp/capt-E.$$.curl";  # capture stderr content
for (my $ti = 0;$ti < @list;$ti++) {
  my $testfile = $list[$ti];
  my $pretty_name = $testfile;
  $pretty_name =~ s#^curltests/##;
  $pretty_name =~ s#/req$##;
  print "\n\n------------------------------------------\n" if $VERBOSE > 1;
  printf("%3.3d/%3.3d Running test '%s'\n",$ti+1,scalar(@list),$pretty_name) if $VERBOSE > 0;
  print "------------------------------------------\n"     if $VERBOSE > 1;

  # Read request specificaltion in .req file
  my $req = qx( cat "$testfile" );
  my ($method,$path,$rest) = split(/\s+/,$req);
  die "Illegal method '$method' in file '$testfile'. Expected GET or POST etc.\n"
    unless $method =~ /^(GET|POST|PATCH|DELETE)$/i;
  $path =~ s#^/+##;
  $path =~ s#ATOK#cbrain_api_token=$ADMIN_TOKEN#;
  $path =~ s#NTOK#cbrain_api_token=$NORMAL_TOKEN#;
  $path =~ s#DTOK#cbrain_api_token=$DEL_TOKEN#;

  # If a .in.json file exist, we will post this in content
  my $indata = "";
  my $infile = $testfile;
  $infile =~ s/req$/in.json/;
  $indata = "--data @\"$infile\"" if -f $infile;

  # JSON in and out
  my $accept = 'application/json';
  my $ctype  = 'application/json';
  my $curl_accept = "-H \"Accept: $accept\"";
  my $curl_type   = "-H \"Content-Type: $ctype\"";

  # Prepare curl command
  my $bashcom = "curl -s -S -D $captH -X $method $indata $curl_accept $curl_type $SCHEME://$HOST:$PORT/$path > $captC 2> $captE";
  print " => Curl command: $bashcom\n" if $VERBOSE > 1;
  my $ret = system($bashcom);

  # Extract HTTP response code from header
  my @headers = split(/\n/,qx( cat $captH ));
  my ($httpcode) = ($headers[0] =~ /\s(\d\d\d)\s/);
  $httpcode ||= "UNK";

  # Extract HTTP content type
  my $resptype = $1 if join("",@headers) =~ /content-type: (\S+)/i;
  $resptype ||= "Unknown";
  $resptype =~ s/;.*//;

  # Extract expected HTTP response code from .out file, if any
  my $outfile = $testfile;
  $outfile =~ s/req$/out/;
  my @outfile = split(/\n/,qx( cat $outfile )) if -f $outfile;
  my $expcode = $outfile[0] || ""; $expcode =~ s/\s+//;
  $expcode ||= "200";

  # Extract expected HTTP content
  my $expcontent = (@outfile > 1 ? join("",@outfile[1 .. $#outfile]) : "");
  $expcontent =~ s/\s+//g;
  # remove dates: "2018-10-19T22:12:42.000Z"
  $expcontent =~ s/"\d\d\d\d-\d\d-\d\d[T\s]\d\d:\d\d:\d\d[\d\.Z]*"/null/g;
  # remove "id":nnn if a POST (create operation)
  $expcontent =~ s/"id":\d+/"id":new/ if $method eq "POST";

  # Extract response HTTP content
  my $content = qx( cat $captC );
  $content =~ s/\s+//g;
  # remove dates: "2018-10-19T22:12:42.000Z"
  $content =~ s/"\d\d\d\d-\d\d-\d\d[T\s]\d\d:\d\d:\d\d[\d\.Z]*"/null/g;
  # remove "id":nnn if a POST (create operation)
  $content =~ s/"id":\d+/"id":new/ if $method eq "POST";

  # Compare responde to expected response
  if ($ret != 0) { # This failure hides all others
    &record_failure($pretty_name, "CURL: $ret");
    print " => Failed: curl did not execute properly\n" if $VERBOSE > 0;
  } else {
    if ($httpcode ne $expcode) {
      &record_failure($pretty_name, "HTTPCODE: $httpcode <> $expcode");
      print " => Failed: got HTTP response code '$httpcode', expected '$expcode'\n" if $VERBOSE > 0;
    }
    if (lc($ctype) ne lc($resptype)) {
      &record_failure($pretty_name, "C_TYPE: $resptype");
      print " => Failed: got type '$resptype', expected '$ctype'\n" if $VERBOSE > 0;
    }
    if (@outfile > 1 && $content ne $expcontent) {
      &record_failure($pretty_name, "CONTENT DIFFERS");
      print " => Failed: expected content differs\n" if $VERBOSE > 0;
      if ($VERBOSE > 4) {
        print "EXP CONTENT:\n$expcontent\nGOT CONTENT:\n$content\n";
      }
    }
  }

  # All ok?
  if (! $FAILED_TESTS{$pretty_name} ) {
    print " => Test succeeded.\n" if $VERBOSE > 1;
  }

  # Print debug diagnostics
  print " => curl return code: $ret\n" if $VERBOSE > 1;
  print "\n => HEADER\n"     if $VERBOSE > 2;
  system("cat $captH")       if $VERBOSE > 2;
  print "\n => CONTENT\n"    if $VERBOSE > 3;
  system("cat $captC")       if $VERBOSE > 3;
  print "\n => CURL ERROR\n" if $VERBOSE > 3;
  system("cat $captE")       if $VERBOSE > 3;

  # Cleanup
  unlink($captC,"$captE",$captH);
}

# All tests passed, return 0
if (scalar(keys(%FAILED_TESTS)) == 0) {
  print "\nAll test finished successfully.\n" if $VERBOSE > 0;
  exit 0;
}

# Oops, some tests failed; exit code is 1+number of failed tests.
print "\nSome tests failed.\n"                         if $VERBOSE > 0;

foreach my $pretty_name (sort keys %FAILED_TESTS) {
  printf " => %-32s : ",$pretty_name                    if $VERBOSE > 0;
  print join(", ",@{$FAILED_TESTS{$pretty_name}}),"\n" if $VERBOSE > 0;
}
exit(1 + scalar(keys(%FAILED_TESTS)));

#############################
#   S U B R O U T I N E S   #
#############################

sub record_failure {
  my ($testname, $message) = @_;
  my $messages = $FAILED_TESTS{$testname} ||= [];
  push(@$messages, $message);
}
