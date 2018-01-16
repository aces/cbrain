This document starts by describing how to create tests for existing, functional code.  Then, the approach
to writing new tests when bugs that have been uncovered pop up will be discussed.  Finally, the document describes the approach to be taken to integrate test-writing into the development of new code. This document assumes the reader has an understanding of basic RSpec constructs, described in [RSpec Basics](RSpec-Basics.html)

## Writing specs for existing code
As an example for the following, we will write the beginning of a spec for the DataProvider model. The first step when writing specs for existing code is to compartmentalize the tests we will be writing. We will first write an outer describe block for the model itself, and a nested describe block for each of the public methods. We will choose an incomplete set of methods to start with (although it would be a good idea to do all of them for a real case), so our spec will start out like this:

```ruby
  describe DataProvider do
    describe "#is_alive?" do
    end
    describe "#cache_prepare" do
    end
  end
```

The next step is to go through and write the examples. If the method ``it``
is called without a block, the example will be considered pending. Thus it is
a good idea to write all the examples out without blocks at the beginning,
and RSpec will keep track of the ones we have not implemented yet. First,
start with the ``#is_alive?`` method. Since ``#is_alive?`` has return values
it is simpler to test. Essentially, we write an example (an ``it``) for each
logical path. This should look something like this:

```ruby
  describe DataProvider do
    describe "#is_alive?" do
      it "should return false when is_alive? is called on offline provider"
      it "should raise and exception when is_alive! is called with an offline provider"
      it "should raise an exception if called but not implemented in a subclass"
      it "should return false if impl_is_alive? returns false"
    end
    describe "#cache_prepare" do
    end
  end
```

The first three are fairly straightforward. We need a data_provider instance to
play with, so we will create one using a ``let`` statement.  Of course, we could also create an
instance variable in a ``before(:each)`` block, but generally "let"s are preferred, since they only instantiate the object once it is used.  Once we have a data provider to use, the first three examples
are fairly straightforward to write.

```ruby
  describe DataProvider do
    let(:provider) { create(:data_provider) }

    describe "#is_alive?" do
      it "should return false when is_alive? is called on offline provider" do
        provider.online = false
        expect(provider.is_alive?).to be_falsey
      end

     it "should raise an exception if called but not implemented in a subclass" do
       expect(lambda{provider.is_alive?}).to raise_error("Error: method not yet implemented in subclass.")
     end

     it "should raise and exception when is_alive! is called with an offline provider" do
       provider.online = false
       expect(lambda{ provider.is_alive! }).to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
     end
      it "should return false if impl_is_alive? returns false"
    end
    describe "#cache_prepare" do
    end
  end
```

Now, the final example is more difficult to write. It is necessary to test using
the return value of a method that is not defined in this class. Several approaches could be
used to solve the problem.  For example, it would be possible to define the method, or
test a subclass of DataProvider. Neither of these solutions is satisfying, since they would involve
effectively testing things outside the scope of the spec. The best method is to use stubbing. Stubbing essentially makes it possible to hijack a method call on any object and fix its return value. The assumption is that the other method is working properly so that it is possible to test how the method we are currently working on reacts to it. Using this method, we have the following:

```ruby
  describe DataProvider do
    let(:provider) { create(:data_provider) }

    describe "#is_alive?" do
      it "should return false when is_alive? is called on offline provider" do
        provider.online = false
        expect(provider.is_alive?).to be_falsey
      end

     it "should raise an exception if called but not implemented in a subclass" do
       expect(lambda{ provider.is_alive? }).to raise_error("Error: method not yet implemented in subclass.")
     end

     it "should raise and exception when is_alive! is called with an offline provider" do
       provider.online = false
       expect(lambda{ provider.is_alive! }).to raise_error
     end
      it "should return false if impl_is_alive? returns false" do
        allow(provider).to receive(:impl_is_alive?).and_return(false)
        provider.online = true
        expect(provider.is_alive?).to be_falsey
      end
    end
    describe "#cache_prepare" do
    end
  end
```

Moving on to the ``#cache_prepare`` method, we encounter several new problems:
* Dependency on another model (Userfile)
* Interactions with external factors (file system)
* Complex logic, with different prerequisites for different paths.
* No testable return values.

The first problem is the dependency on another model. We could, of course,
use a factory to create a full Userfile to use with the method. But here it
does not seem desirable to use a full Userfile object. Aside from the
overhead of instantiating the full object, there is also the concern that
interaction with the Userfile object may have undesirable side effects (e.g.
interaction with the file system). In this case, we can take advantage
of RSpec's mocking framework, to create a dummy object that simply has
a few stubbed methods that we need:

```ruby
  describe DataProvider do
    let(:provider) { create(:data_provider) }
    let(:userfile) { double("userfile", :name => "userfile_double", :id => 123) }

    describe "#is_alive?" do
      ....
    end
    describe "#cache_prepare" do
    end
  end
```

A mock is a dummy object. By default, it will not respond to any methods. If
we need certain methods to be defined, we can stub them (which is done here
with the hash argument to the double method). Finally, if we simply want
our mock to respond to any methods called on it without doing anything,
we can call ``#is_null_object`` on it (it will return nil for any methods called
that are not stubbed to do otherwise).

Note also that rspec-mocks provides some special mocking methods for mocking
ActiveRecord objects.
* ``mock_model``: create a mock with some basic ActiveRecord methods stubbed out
(e.g. id, valid?, new_record?, etc.). Optionally takes a single argument to describe
which model is being mocked (for error messages, etc.)
* ``stub_model(class)``: this method will actually create object of the ActiveRecord
subclass given, but with methods stubbed out so as not to interact with the db.

For our purposes, we will use ``mock_model`` avoid having to define an id:

```ruby
  describe DataProvider do
    let(:provider) { create(:data_provider) }
    let(:userfile) { mock_model(Userfile, :name => "userfile_double") }

    describe "#is_alive?" do
      ....
    end
    describe "#cache_prepare" do
    end
  end
```

Now comes the question of choosing the examples. There are two factors to consider
here. The first is that generally, when we write tests, we want to be testing the
API, and not the implementation.  It is not really important how a method is doing what it is
doing (e.g. using an array vs. a hash table), as long as it works. On the other hand,
since ``#cache_prepare`` whose effect is not seen through the API, but through its effect on
the file system, we have to find some way to test that it is doing what it is supposed to be doing.
There may be several ways to do this. Here we have chosen to define some high-level actions that
the method is expected to perform. The method should check that the data provider is in a valid state,
should check that the cache is ready to be modified, should locate the cache's base directory, and
finally, it should attempt to  create a subdirectory to store the file if and only if it does not
yet exist. Later, these actions will be mapped to internal method calls. This will render the tests
somewhat brittle, since changes to the implementation of the method, even if they do not affect
behavior, could cause the test to fail. It is for this reason that testing internal implementation
should be approached with care.

```ruby
  describe DataProvider do
    let(:provider) { create(:data_provider) }
    let(:userfile) { mock_model(Userfile, :name => "userfile_double") }

    describe "#is_alive?" do
      ....
    end
    describe "#cache_prepare" do
      it "should raise an exception if not online"
      it "should raise an exception if read only"
      it "should ensure that the cache is ready to be modified"
      it "should raise an exception if passed a string argument"
      it "should find the cache root"
      it "should create the subdirectory if it does not exist"
      it "should not attempt to create the subdirectory if it already exists"
    end
  end
```

The first two examples test to ensure that the object is in a valid state before
attempting to prepare the cache. The checks are done at the beginning of the method
and do not have any preconditions, so we can just fill their examples in:

```ruby
  describe DataProvider do
    let(:provider) { create(:data_provider) }
    let(:userfile) { mock_model(Userfile, :name => "userfile_double") }

    describe "#is_alive?" do
      ....
    end
    describe "#cache_prepare" do
      it "should raise an exception if not online" do
        provider.online = false
        expect(lambda{ provider.cache_prepare(userfile) }).to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
      end
      it "should raise an exception if read only" do
         provider.read_only = true
         expect(lambda{provider.cache_prepare(userfile)}).to raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
      end
      it "should ensure that the cache is ready to be modified"
      it "should raise an exception if passed a string argument"
      it "should find the cache root"
      it "should create the subdirectory if it does not exist"
      it "should not attempt to create the subdirectory if it already exists"
    end
  end
```

The remainder of the method, however, is more complex. It interacts with other
methods in the class, it makes checks on the file system, etc. As before,
we will stub out the methods used for these interactions. We could stub the
methods separately for each example, but since they all have similar requirements,
we can DRY out the stubbing by creating a context block around the remaining methods,
and using a ``before(:each)`` for the stubbing:

```ruby
  describe DataProvider do
    let(:provider) { create(:data_provider) }
    let(:userfile) { mock_model(Userfile, :name => "userfile_double") }

    describe "#is_alive?" do
      ....
    end
    describe "#cache_prepare" do
      it "should raise an exception if not online" do
        provider.online = false
        expect(lambda{ provider.cache_prepare(userfile) }).to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
      end
      it "should raise an exception if read only" do
         provider.read_only = true
         expect(lambda{ provider.cache_prepare(userfile) }).to raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
      end
      context "creating a cache subdirectory" do
        before(:each) do
          allow(SyncStatus).to receive(:ready_to_modify_cache).and_yield
          allow(DataProvider).to receive(:cache_rootdir).and_return("cache")
          allow(File).to receive(:directory?).and_return(false)
          allow(Dir).to receive(:mkdir)
        end
        it "should ensure that the cache is ready to be modified"
        it "should raise an exception if passed a string argument"
        it "should find the cache root"
        it "should create the subdirectory if it does not exist"
        it "should not attempt to create the subdirectory if it already exists"
      end
    end
  end
```

Now we can write our examples. For most examples, the approach is simply to customize
the stubbing, if necessary, and then use ``#expect*receive`` to ensure that critical
methods are being called:

```ruby
  describe DataProvider do
    let(:provider) { create(:data_provider) }
    let(:userfile) { mock_model(Userfile, :name => "userfile_double") }

    describe "#is_alive?" do
      ....
    end
    describe "#cache_prepare" do
      it "should raise an exception if not online" do
        provider.online = false
        expect(lambda{ provider.cache_prepare(userfile) }).to raise_error(CbrainError, "Error: provider #{provider.name} is offline.")
      end
      it "should raise an exception if read only" do
         provider.read_only = true
         expect(lambda{ provider.cache_prepare(userfile) }).to raise_error(CbrainError, "Error: provider #{provider.name} is read_only.")
      end
      context "creating a cache subdirectory" do
        before(:each) do
          allow(SyncStatus).to receive(:ready_to_modify_cache).and_yield
          allow(DataProvider).to receive(:cache_rootdir).and_return("cache")
          allow(File).to receive(:directory?).and_return(false)
          allow(Dir).to receive(:mkdir)
        end
        it "should ensure that the cache is ready to be modified" do
          expect(SyncStatus).to receive(:ready_to_modify_cache)
          expect(provider.cache_prepare(userfile)).to be_truthy
        end
        it "should raise an exception if passed a string argument" do
          expect(lambda{ provider.cache_prepare("userfile") }).to raise_error(CbrainError, "DataProvider internal API change incompatibility (string vs userfile)")
        end
        it "should create the subdirectory if it does not exist" do
          expect(Dir).to receive(:mkdir).at_least(:once)
          expect(provider.cache_prepare(userfile)).to be_truthy
        end
        it "should not attempt to create the subdirectory if it already exists" do
          allow(File).to receive(:directory?).and_return(true)
          expect(Dir).not_to receive(:mkdir)
          expect(provider.cache_prepare(userfile)).to be_truthy
        end
      end
    end
  end
```

## Writing specs to debug code

If we find a bug in our code that did not cause an example to fail, this
indicates to us that our test suite is incomplete. Before debugging the
actual code, the first step is to write the missing example. Write the example
so that it fails because of the bug. Then write the code to make the example pass.
For example, if we have a simple ``MyMath`` class with a method to calculate the square of
a number:

```ruby
  class MyMath
    # Return the square of n.
    def self.square(n)
      n * 2
    end
  end
```

Clearly, the ``#square`` method has a bug. Despite the fact that it would be fairly simple to fix,
our first step will be to write the failing example:

```ruby
  describe MyMath do
    describe "#square" do
      it "should return the square of a number" do
        MyMath.square(3).to eq(9)
      end
    end
  end
```

This test will fail, and now we know that the code is covered (however incompletely).
So now we have the coverage on this method so we can modify the method:

```ruby
  class MyMath
    # Return the square of n.
    def self.square(n)
      n ** 2
    end
  end
```

And now the method will work. Obviously, a proper spec would have more examples,
but this should suffice give a general sense of how tests can be maintained and
updated while debugging.

## Writing specs for new code (BDD)

In order to ensure that the specs are kept up-to-date with respect to the code,
we will implement some approaches of behavior driven development (BDD) to our coding
practices. Essentially, BDD attempts to shift the focus of development to the behavior
of the code. This is done by first writing specs (in RSpec for us) to define what we
want the code to do. The specs should essentially define the API for a piece of code.
We are not interested in how code does what it does (i.e. testing the implementation).
We just want to make sure that when other code interacts with it, that it behaves
properly. At first all the specs will fail (not be satisfied), and then we begin to
write code to satisfy the specs. When we are done, the specs act as regression tests,
ensuring that we do not break old code when writing new code.

As an example, we will assume the ``MyMath`` class from the previous section has not been
written and we will write it using BDD. One of the tricks to BDD is to make the
specs as granular as possible. This involves a certain amount of "playing dumb" that
will be counter-intuitive, but the end result will be better coverage for our specs.
So let's start with a basic case:

```ruby
  describe MyMath do
    describe "#square" do
      it "should return 0 for 0" do
        expect(MyMath.square(0)).to eq(0)
      end
    end
  end
```

This will fail because the class has not been written yet, so we will write EXACTLY
enough code to get it to pass:

```ruby
  class MyMath
    # Return the square of n.
    def self.square(n)
      0
    end
  end
```

This will get the spec to pass. Now we write another example:

```ruby
  describe MyMath do
    describe "#square" do
      it "should return 0 for 0" do
        expect(MyMath.square(0)).to eq(0)
      end
      it "should return 1 for 1" do
        expect(MyMath.square(1)).to eq(1)
      end
    end
  end
```

Another failure so we add the necessary code:

```ruby
 class MyMath
   # Return the square of n.
   def self.square(n)
     if n == 0
       0
     else
       1
     end
   end
 end
```

The spec passes. Now to speed things up, we will add two more examples:

```ruby
  describe MyMath do
    describe "#square" do
      it "should return 0 for 0" do
        expect(MyMath.square(0)).to eq(0)
      end
      it "should return 1 for 1" do
        expect(MyMath.square(1)).to eq(1)
      end
      it "should return 4 for 2" do
        expect(MyMath.square(2)).to eq(4)
      end
      it "should return 9 for 3" do
        expect(MyMath.square(3)).to eq(9)
      end
    end
  end
```

At this point we have a bit of coverage, so we can attempt to
write the generalized version of the method.

```ruby
  class MyMath
    # Return the square of n.
    def self.square(n)
      n * n
    end
  end
```

All the tests pass. The take home message from this example is to let the specs
dictate the writing of the code. This way, we ensure that the coverage of the specs
is broad and we do not write any code that we do not plan on using.

**Note**: Original author of this document is Tarek Sherif.