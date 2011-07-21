require 'spec_helper'

describe TagsController do
  let(:tag) {mock_model(Tag).as_null_object}
  let(:current_user) {Factory.create(:user)}

  context "with a logged in user" do
    before(:each) do
      session[:user_id] = current_user.id
    end

    describe "new" do
      before(:each) do
        Tag.stub!(:new).and_return(tag)
      end

      it "should assign @tag" do
        get :new
        assigns[:tag].should == tag
      end
      it "should creates a new object" do 
        Tag.should_receive(:new).with(:group_id => current_user.own_group.id)
        get :new  
      end
    end

    describe "edit" do
      let(:real_tag) {Factory.create(:tag, :user_id => current_user.id)}
      
      it "should find the requested tag" do
        get :edit, :id => real_tag.id
        assigns[:tag].should == real_tag
      end
      it "should render the edit page" do
        get :edit, :id => real_tag.id
        response.should render_template("edit")
      end
    end

    describe "create" do
      before(:each) do
        Tag.stub!(:new).and_return(tag)
      end

      it "should create a new tag object with given params" do
        Tag.should_receive(:new).with("name" => "name", "user_id" => current_user.id.to_s)
        post :create, :tag => { :name => "name", :user_id => current_user.id.to_s}
      end
      it "should assign the tag to the current user" do
        tag.should_receive(:user_id=).with(current_user.id)
        post :create
      end
      it "should save the record" do
        tag.should_receive(:save)
        post :create
      end
      it "should render the create page" do
          post :create, :format => "js"
          response.should render_template("create") 
      end
      
      context "when save is successful" do
        before(:each) do
          tag.stub!(:save).and_return(true)
        end

        it "should display a flash message" do
          post :create
          flash[:notice].should == 'Tag was successfully created.'
        end
        it "should redirect to the index" do
          post :create
          response.should redirect_to(:action => :index, :controller => :userfiles)
        end
      end
  
      context "when save is unsuccesful" do
        before(:each) do
          tag.stub!(:save).and_return(false)
        end
        
        it "should render the edit page" do
          post :create
          response.should redirect_to(:action => :index, :controller => :userfiles)
        end
      end
    end

    describe "update" do
      let(:real_tag) {Factory.create(:tag, :name => "name", :user_id => current_user.id)}
      
      it "should find the requested tag" do
        get :edit, :id => real_tag.id
        assigns[:tag].should == real_tag
      end
      it "should render the create page when js is requested" do
        put :update, :id => real_tag.id,  :format => "js"
        response.should render_template(:action => "update")
      end
      
      context "when update is successful" do
        it "should display a flash message" do
          put :update, :id => real_tag.id
          flash[:notice].should == "Tag was successfully updated."
        end
        it "should redirect to the userfile index page" do
          put :update, :id => real_tag.id
          response.should redirect_to(:action => :index, :controller => :userfiles)
        end
        
      end

      # html case
      # response.should redirect_to(:action => :index, :controller => :userfiles)

      
      context "when update fails" do
        it "should render the edit page" do
          put :update, :id => real_tag.id.to_s,:tag => {"name" => '#'}
          response.should render_template("edit")
        end
      end
    end

    describe "destroy" do
      let(:real_tag) {Factory.create(:tag, :user_id => current_user.id)}
      before(:each) do 
        session[:userfiles] ||= {} 
      end
      
      it "should find the requested tag" do
        delete :destroy, :id => real_tag.id
        assigns[:tag].should == real_tag
      end

      it "should call delete on session[:userfiles][filter_tags_array]" do
        session[:userfiles]["filter_tags_array"] = [real_tag.id.to_s]
        session[:userfiles]["filter_tags_array"].should_receive(:delete)
        delete :destroy, :id => real_tag.id.to_s
      end
      
      it "should redirect to index for an html request" do
        delete :destroy, :id => real_tag.id.to_s, :format => "html"
        response.should redirect_to(:action => :index, :controller => :userfiles)
      end
      it "should render the update_tag_table js script for a script request" do
        delete :destroy, :id => real_tag.id, :format => "js"
        response.should render_template("tags/_update_tag_table")
      end
    end
  end

  
  context "when the user is not logged in" do
    describe "index" do
      it "should redirect the login page" do
        get :index
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    
    describe "show" do
      it "should redirect the login page" do
        get :show, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    
    describe "edit" do
      it "should redirect the login page" do
        get :edit, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    
    describe "create" do
      it "should redirect the login page" do
        post :create
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    
    describe "update" do
      it "should redirect the login page" do
        put :update, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    
    describe "destroy" do
      it "should redirect the login page" do
        delete :destroy, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
  end
end
