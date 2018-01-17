The following is a basic introduction to some of the basic constructs
in RSpec. This is by no means a complete guide, but should be enough
to get started writing specs.

## Specs and examples
A set of tests for a given aspect of the code (class, module, method) is
referred to as a **spec** and the individual tests are **examples**. The
first step when writing a spec is to require the ``spec_helper`` file, and
then create a ``describe`` block which defines what we're writing a spec for.

For example, to write a spec for the Group model, we would start
like this:

```ruby
  require 'spec_helper'

  describe Group do
  end
```

Describe blocks can be nested, so the next step would be to add a describe
block for each method we wish to test. To keep things simple, we will just
write a spec for the ``#pretty_category_name`` method:

```ruby
  require 'spec_helper'

  describe Group do
    describe "#pretty_category_name" do
    end
  end
```

Now that things are organized, we can write some examples. To do this
we write some ``it`` blocks for the different cases we wish to test.
Since ``#pretty_category_name`` only has one line we will write an example describing
how it should function:

```ruby
  require 'spec_helper'

  describe Group do
    describe "#pretty_category_name" do
      it "should convert the suffix 'Group' of a class name to 'Project'"
    end
  end
```

When the method ``it`` is called this way, without a block, the example is
considered **pending**. We can fill it in with some code to test the method.

```ruby
  require 'spec_helper'

  describe Group do
    describe "#pretty_category_name" do
      it "should convert the suffix 'Group' of a class name to 'Project'" do
        group = SystemGroup.create!(:name => "sys_group")
        user  = User.create!(:login => "login", "password" => "password", ...)
        expect(group.pretty_category_name(user)).to eq("System Project")
      end
    end
  end
```

This is not ideal for a few different reasons:
* First, we are testing a class (SystemGroup) other than the one we are writing the spec for (Group).
* Second, the messy creation of the objects will become quite cumbersome if they have to
be repeated for each example.
* Finally, the simple fact of having to define ALL attributes on a created object (e.g. because of the many validations on User) makes the code messy and draws focus away from what we are supposed be testing.

Let's deal with the issues one at a time. First, we can pull the object creation
out of the example in two ways. The first is defining instance variables in a
``before(:each)`` block. A ``before(:each)`` block is simply some code run before each
example in a given describe block, and can be used for set up:

```ruby
  describe Group do
    before(:each) do
      @group = SystemGroup.create!(:name => "sys_group")
      @user  = User.create!(:login => "login", "password" => "password", ...)
    end

    describe "#pretty_category_name" do
      it "should convert the suffix 'Group' of a class name to 'Project'" do
        expect(@group.pretty_category_name(@user)).to eq("System Project")
      end
    end
  end
```

The other way is to use ``let`` statements. While ``before(:each)`` blocks can
be used to run arbitrary code, let statements are specifically for setting up
variables. In general, they are preferable, since they load lazily, i.e.
the object isn't instantiated until the variable is used:

```ruby
  describe Group do
    let(:group) { SystemGroup.create!(:name => "sys_group") }
    let(:user)  { User.create!(:login => "login", "password" => "password", ...) }

    describe "#pretty_category_name" do
      it "should convert the suffix 'Group' of a class name to 'Project'" do
        expect(group.pretty_category_name(user)).to eq("System Project")
      end
    end
  end
```

Note that the ``@`` marker is no longer used. Now to avoid having to clutter our
code with the definition of attributes we're not even testing, we can use factories.
Factories allows us to create and save models with reasonable attributes. To use them, we define them in the file: "spec/factories/portal_factories.rb". We can add the factories we need in the following way:

```ruby
  #################
  # User          #
  #################

  factory :user, class: NormalUser do
    sequence(:login)      { |n| "user#{n}" }
    sequence(:full_name)  { |n| "Bob #{n}" }
    sequence(:email)      { |n| "user#{n}@example.com" }
    password              "Password!"
    password_confirmation "Password!"
  end

  factory :normal_user, parent: :user, class: NormalUser do
    sequence(:login)      { |n| "normal_user_#{n}" }
  end

  #################
  # Group         #
  #################

  factory :group do
    sequence(:name) { |n| "group_#{n}" }
  end
```

And then, we can simplify our spec code as follows:

```ruby
  describe Group do
    let(:group) { create(:group) }
    let(:user)  { create(:user) }

    describe "#pretty_category_name" do
      it "should convert the suffix 'Group' of a class name to 'Project'" do
        expect(group.pretty_category_name(user)).to eq("System Project")
      end
    end
  end
```

This creates the instance we need to run the code. Note that factories also have
a ``build`` method to instantiate an object without saving it to the database. We
have a problem now, however, in that the group is no longer a SystemGroup, and so
will not produce the expected string. Furthermore, since the method is not meant to
be used with the base Group class, we will get odd results. We could create another
factory for a subclass of Group, but that would be overkill. All we need is one method:
class. So instead of instantiating a whole new object, we can just stub the class
method.

Stubbing is a testing technique whereby we intercept method calls on an object, either
to block them or fix their return values. We can do so in the following way to stub the
``#class`` method:

```ruby
  describe Group do
    let(:group) { create(:group) }
    let(:user)  { create(:user) }

    describe "#pretty_category_name" do
      it "should convert the suffix 'Group' of a class name to 'Project'" do
        allow(group).to receive(:class).and_return(SystemGroup)
        expect(group.pretty_category_name(user)).to eq("System Project")
      end
    end
  end
```

This idea of overkill is apparent as well in the case of the user object. It seems unnecessary
to create an entire User object, just to pass it the method, and it is easier to use
a mock object in this case. A mock object is a dummy object that simply takes the place of another object without doing anything. By default, it will not respond to any methods. Methods can be stubbed to add needed functionality. There are three methods we can use to create mock objects (See [RSpec::ActiveModel::Mocks](https://github.com/rspec/rspec-activemodel-mocks#rspecactivemodelmocks-)):
* ``double``: create a basic mock object with no methods. A string is given as a first argument,
this string is used to make error messages more readable. A hash can be given as second argument
to conveniently define stubs.
* ``mock_model``: create a mock ActiveRecord object. This mock will have a few basic ActiveRecord
methods already stubbed out. Also, an optional argument can be given to define which model is
being mocked (allowing the model to respond to ``#is_a?`` and ``#class``).
* ``stub_model(model)``: create an instance of the actual ActiveRecord model, but with methods
interacting with the db stubbed out.

For our purposes, we do not need any ActiveRecord functionality, so we can just use the standard
double method.

```ruby
  describe Group do
    let(:group) { create(:group) }
    let(:user)  { double("user") }

    describe "#pretty_category_name" do
      it "should convert the suffix 'Group' of a class name to 'Project'" do
        allow(group).to receive(:class).and_return(SystemGroup)
        expect(group.pretty_category_name(user)).to eq("System Project")
      end
    end
  end
```

By default, a mock object will only respond to methods that have been stubbed on it. If we
find ourselves needing a mock object on which methods will be called, but without really being
concerned about their return values, we can create a mock as a null object. A null object
will respond to any methods stubbed on it with the return values defined, and will accept
and ignore any other method calls without raising a MethodMissing exception. To convert
a standard mock into a null object, we simply call the ``#as_null_object`` method on it:

```ruby
  double("user").as_null_object
```

For the current example, however, this is unnecessary.

## Matchers

One line that we did not discuss in the previous section was the line that actually
defined our expectation:

```ruby
  expect(group.pretty_category_name(user)).to eq("System Project")
```

RSpec has a very rich set of [built in matchers](https://relishapp.com/rspec/rspec-expectations/v/3-2/docs/built-in-matchers) to allow us to define our specs.

One simple way to produce a matcher is to use RSpec's be_xxx matchers. The xxx part of the
method name should be a predicate method defined on the object being tested.
For example:

```ruby
  it "should not consider an empty object valid" do
    expect(Group.new).not_to be_valid
  end
```

The ``be_valid`` matcher will call the ``#valid?`` method on the user object to test
the expectation. Another example would be:

```ruby
  it "should start out with no users" do
    expect(create(:group).users).to be_empty
  end
```

This calls the ``#empty?`` method on the return value from the call to users.

There are also matchers for class comparisons. The ``be_a`` matcher uses ``#is_a?`` to
compare classes:

```ruby
  it "should be a Group" do
    expect(SystemGroup.new).to be_a(Group)
  end
```

The ``be_an_instance_of`` requires that the classes match exactly:

```ruby
  it "should not be an instance of Group" do
    expect(SystemGroup.new).not_to be_an_instance_of(Group)
  end
```

We can also define expectations on method calls using the ``receive`` method.
In the DataProvider class, we expect the ``#cache_prepare method`` to check that
the cache is ready to be modified before creating directories. This
expectation can be written as:

```ruby
  it "should ensure that the cache is ready to be modified" do
    expect(SyncStatus).to receive(:ready_to_modify_cache)
    expect(provider.cache_prepare(userfile)).to be_truthy
  end
```

Note that the expectation is defined before the method is actually called.
Also, not that a ``#receive`` call also effectively stubs out the method.
This is by no means an exhaustive list of the types of matchers available in
RSpec. For more documentation about all the matchers available see: [https://relishapp.com/rspec/rspec-expectations/v/3-2/docs/built-in-matchers](https://relishapp.com/rspec/rspec-expectations/v/3-2/docs/built-in-matchers)

For more information, consult the [RSpec book](https://pragprog.com/book/achbd/the-rspec-book) or [online documentation about RSpec 3.2](https://relishapp.com/rspec/rspec-expectations/v/3-2/docs).

**Note**: Original author of this document on RSpec is Tarek Sherif.