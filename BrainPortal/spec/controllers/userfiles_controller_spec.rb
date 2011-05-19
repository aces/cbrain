require 'spec_helper'

describe UserfilesController do
  
  it "should list no files when user has no files" do
    get :index
  end
  
end

