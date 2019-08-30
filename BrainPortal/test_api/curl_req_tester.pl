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
relative paths to the "req" files under "req_files/", e.g. "normget"
or "groups/create" or "groups" etc. This is not a regex or a pattern,
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
my %FAILED_TESTS = (); # pretty_test_name => [ type, type, ... ] ; type any of CURL, CONTENT-TYPE, CONTENT, HTTPCODE

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
            &Usage;
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

&Usage if @ARGV != 0 && $ARGV[0] =~ /^-/;
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
die "This program must be run in the BrainPortal/test_api directory.\n" unless -f "curl_req_tester.pl" && -d "req_files";

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
my @list = qx( find req_files -type f -name '*req' -print );
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
my $new_order = &shuffle_req_files(\@list);
@list = @$new_order; # replace
print "\nReordered list.\n"            if $VERBOSE > 1;
print " => ",join("\n => ",@list),"\n" if $VERBOSE > 2;

# Process each of them
my $captH = "/tmp/capt-H.$$.curl";  # capture response header
my $captC = "/tmp/capt-C.$$.curl";  # capture response content
my $captE = "/tmp/capt-E.$$.curl";  # capture stderr content
for (my $ti = 0;$ti < @list;$ti++) {
  my $testfile = $list[$ti];
  my $testbase = $testfile; $testbase =~ s/req$//; # used to build other related files
  my $pretty_name = $testbase;
  $pretty_name =~ s#^req_files/##;
  $pretty_name =~ s#[\/\.\-]?$##;
  $pretty_name = sprintf("%2.2d/%2.2d : %s",$ti+1,scalar(@list),$pretty_name);
  print "\n\n------------------------------------------\n" if $VERBOSE > 1;
  print "Running test $pretty_name\n"                      if $VERBOSE > 0;
  print "------------------------------------------\n"     if $VERBOSE > 1;

  # Read request specification in .req file
  my $req = qx( cat "$testfile" );
  my ($method,$path,$ctype,$control) = split(/\s+/,$req);

  if (($control || "") =~ /NoCurlClient/) {
    print " => Test skipped.\n";
    next;
  }

  die "Illegal method '$method' in file '$testfile'. Expected GET or POST etc.\n"
    unless $method =~ /^(GET|POST|PATCH|PUT|DELETE)$/i;
  $path =~ s#^/+##;
  $path =~ s#ATOK#cbrain_api_token=$ADMIN_TOKEN#;
  $path =~ s#NTOK#cbrain_api_token=$NORMAL_TOKEN#;
  $path =~ s#DTOK#cbrain_api_token=$DEL_TOKEN#;

  # If a .in.json file exist, we will post this in content
  my $indata = "";
  my $infile = $testbase . "in.json";
  $indata = "--data @\"$infile\"" if -f $infile;

  # If a .in.form file exist, we will read its content and
  # build a set of key=value to post as a multipart
  my $inform = "";
  my $formfile = $testbase . "in.form";
  if (-f $formfile) {
    my @content=`cat $formfile`;
    chomp @content;
    foreach (@content) { # mutate
      s/__REQBASE__/$testbase/g;
      $inform .= " -F '$_' ";
    }
  }

  # JSON in and out by default
  my $accept   = 'application/json';
  $ctype     ||= 'application/json';

  # Extract expected HTTP response code from .out file, if any
  my $outfile = $testbase . "out";
  my @outfile = split(/\n/,qx( cat $outfile )) if -f $outfile;
  my $expcode = "200";
  my @zap_regex = ();
  if (@outfile > 0) {
    $outfile[0] =~ s/^\s*//;
    $outfile[0] =~ s/\s*$//;
    my @info = split(/\s+/,$outfile[0]); # "200 application/json regex regex regex"
    $expcode = $info[0] if @info > 0;
    $accept  = $info[1] if @info > 1;
    @zap_regex = @info[2..$#info] if @info > 2;
  }

  # Extract expected HTTP content
  my $expcontent = (@outfile > 1 ? join("",@outfile[1 .. $#outfile]) : "");
  $expcontent = &filter_content($expcontent, \@zap_regex );
  # remove "id":nnn if a POST (create operation)
  $expcontent = &filter_content($expcontent, [ '"id":\d+' ]) if $method eq "POST";

  # Prepare curl command
  my $curl_accept = "-H \"Accept: $accept\"";
  my $curl_type   = "-H \"Content-Type: $ctype\"";
  my $bashcom = "curl -s -S -D $captH -X $method $indata $inform $curl_accept $curl_type $SCHEME://$HOST:$PORT/$path > $captC 2> $captE";
  print " => Curl command: $bashcom\n" if $VERBOSE > 1;
  my $ret = system($bashcom);

  # Extract HTTP response code from header
  my @headers = split(/\n/,qx( cat $captH ));
  my $httpcode = "UNK";
  foreach my $header (reverse @headers) {
    next unless $header =~ /HTTP\/[\d\.]+\s+(\d\d\d+)/;
    $httpcode = $1;
    last;
  }

  # Extract HTTP content type
  my $resptype = $1 if join("",@headers) =~ /content-type: (\S+)/i;
  $resptype ||= "Unknown";
  $resptype =~ s/;.*//;

  # Extract response HTTP content
  my $content = qx( cat $captC );
  $content = &filter_content($content, \@zap_regex );
  # remove "id":nnn if a POST (create operation)
  $content = &filter_content($content, [ '"id":\d+' ]) if $method eq "POST";

  # Compare responde to expected response
  if ($ret != 0) { # This failure hides all others
    &record_failure($pretty_name, "CURL: $ret");
    print " => Failed: curl did not execute properly\n" if $VERBOSE > 0;
  } else {
    if ($httpcode ne $expcode) {
      &record_failure($pretty_name, "HTTPCODE: $httpcode <> $expcode");
      print " => Failed: got HTTP response code '$httpcode', expected '$expcode'\n" if $VERBOSE > 0;
    }
    if (lc($accept) ne lc($resptype)) {
      &record_failure($pretty_name, "C_TYPE: $resptype");
      print " => Failed: got type '$resptype', expected '$accept'\n" if $VERBOSE > 0;
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
  printf " => %-50s : ",$pretty_name                    if $VERBOSE > 0;
  print join(", ",@{$FAILED_TESTS{$pretty_name}}),"\n" if $VERBOSE > 0;
}
exit(scalar(keys(%FAILED_TESTS)));

#############################
#   S U B R O U T I N E S   #
#############################

sub record_failure {
  my ($testname, $message) = @_;
  my $messages = $FAILED_TESTS{$testname} ||= [];
  push(@$messages, $message);
}

# Shuffling req files is special, in that
# req files at the lowest level of a directory
# tree must be tried in alphabetcal order,
# but aside from that they shoudl be able to be
# run in arbitrary order compared to any other req
# files elsewhere.
sub shuffle_req_files {
  my $listref = $_[0]; # array of relative path names of req files

  # Build index of common dir prefixes
  my %regrouping = ();
  foreach my $req (@$listref) {
    my $prefix = $req;
    $prefix =~ s#/[^\/]+$##; # remove trailing "/anything"
    my $sublist = $regrouping{$prefix} ||= [];
    push(@$sublist, $req);
  }

  # Build shuffled list of prefixes
  # Oh do I miss Ruby's .shuffle().
  my @prefixes = keys %regrouping;
  for (my $i=0;$i<@prefixes;$i++) {
    my $j = int(rand(@prefixes));
    my $vi = $prefixes[$i];
    my $vj = $prefixes[$j];
    $prefixes[$i] = $vj;
    $prefixes[$j] = $vi;
  }

  # Return list of all req files such that
  # prefixes are shuffled, yet files with same
  # prefixes are ordered.
  my $new_order = [];
  foreach my $prefix (@prefixes) { # now shuffled
    my $sublist = $regrouping{$prefix};
    push(@$new_order,sort(@$sublist));
  }
  return $new_order;
}

sub filter_content {
  my ($content,$regex_list) = @_;
  $content =~ s/:(true|false)/:"$1"/g;
  foreach my $regex ('\s+', '"\d\d\d\d-\d\d-\d\d[T\s]\d\d:\d\d:\d\d[\d\.Z]*"', @$regex_list) {
    $content =~ s/$regex//g;
  }
  return $content;
}

