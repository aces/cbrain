class CBRAINMessage < Exception
  attr_accessor :redirect, :type
  
  def initialize(message, redirect = {:action  => :index}, type = :notice)
    @redirect = redirect
    @type = type.to_sym
    super(message)
  end
end

def cb_notify(message = "Something went wrong.", redirect = {:action  => :index})
  raise CBRAINMessage.new(message, redirect, :notice)
end

def cb_error(message = "Something went wrong.", redirect = {:action  => :index})
  raise CBRAINMessage.new(message, redirect, :error)
end