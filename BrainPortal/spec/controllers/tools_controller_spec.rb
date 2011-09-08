require 'spec_helper'

describe ToolsController do
  let(:tool) {mock_model(Tool).as_null_object}
  
  context "with a logged in user" do
    context "user is an admin" do
      let(:current_user) {Factory.create(:user, :role => "admin")}
      before(:each) do
        session[:user_id] = current_user.id
      end
  
      describe "index", :current => true do
        before(:each) do
          controller.stub_chain(:base_filtered_scope ,:includes, :order).and_return([tool])
        end
        
        it "should assign @tools" do
          get :index
          assigns[:tools].should == [tool]
        end
        it "should render the index page" do
          get :index
          response.should render_template("index")
        end
      end
  
      describe "bourreau_select" do
        let(:real_tool) {Factory.create(:tool, :user_id => current_user.id )}
  
        it "should render empty text if current_value is empty" do
          get(:bourreau_select, {'current_value' => ""})
          response.body.should be_empty
        end
  
        it "should render bourreau_select" do
          get(:bourreau_select,{'current_value' => real_tool.id.to_s})
          response.should render_template("tools/_bourreau_select")
        end 
        
        it "should display error text if go in rescue" do
          get(:bourreau_select, {'current_value' => "abc"})
          response.body.should =~ /No Execution Servers/
        end
      end
  
      describe "edit" do
  
        it "should redirect to tools" do
          get(:edit, {"id" => "1"})
          response.should redirect_to("/tools")
        end
      end
  
      describe "create" do
        let(:mock_tool) {mock_model(Tool).as_null_object}
        
        it "should autoload_all_tools if autoload is defined" do
          controller.stub!(:render)
          controller.should_receive(:autoload_all_tools)
          post :create, :tool => {}, :autoload => "true", :format => "js"
        end

        context "when save is successful" do
          before(:each) do
            Tool.stub!(:new).and_return(mock_tool)
            mock_tool.stub_chain(:errors, :add)
            mock_tool.stub!(:save).and_return(true)
            mock_tool.stub_chain(:errors, :empty?).and_return(true)
          end
          
          it "should send a flash notice" do
            post :create, :tool => {}
            flash[:notice].should  be_true
          end
          it "should redirect to the index" do
            post(:create, :tool => {:name => "name"}, :format => "js")
            response.should redirect_to(:action => :index, :format => :js)
          end          
        end

        context "when save failed" do
          before(:each) do
            Tool.stub!(:new).and_return(mock_tool)
            mock_tool.stub_chain(:errors, :add)
            mock_tool.stub!(:save).and_return(false)
            mock_tool.stub_chain(:errors, :empty?).and_return(false)
          end
          
          it "should render 'failed create' partial" do
            post(:create, :tool => {:name => "name"},:format => "js")
            response.should render_template("shared/_failed_create")
          end
        end
      
      end
  
      describe "update" do
        let(:real_tool) {Factory.create(:tool, :user_id => current_user.id )}
  
        it "should find available tools" do
          put :update, :id => real_tool.id
          assigns[:tool].should == real_tool
        end
  
        context "when update is successful" do
          it "should display a flash message" do
            put :update, :id => real_tool.id
            flash[:notice].should == "Tool was successfully updated."
          end
        end
  
        context "when update fails" do
          let(:mock_tool) {mock_model(Tool).as_null_object}

          it "should render the edit page" do
            put :update, :id => real_tool.id, :tool => {:name => ""} 
            response.should render_template("edit")
          end
        end
      end
  
      describe "destroy" do
        let(:real_tool) {Factory.create(:tool, :user_id => current_user.id )}
        
        it "should find the requested tag" do
          delete :destroy, :id => real_tool.id
          assigns[:tool].should == real_tool
        end
        it "should allow me to destroy a tool" do
          delete :destroy, :id => real_tool.id
          Tool.all.should_not include(real_tool)
        end
        it "should redirect to the index" do
          delete :destroy, :id => real_tool.id, :format => "js"
          response.should redirect_to(:action => :index, :format => :js)
        end
      end
  
      describe "tool_managment" do
  
        it "should call find on Tool" do
          Tool.should_receive(:order)
          get :tool_management
        end
  
        it "should assign bourreaux" do
          Bourreau.should_receive(:all)
          get :tool_management
        end
        it "should render tamplate tool_manager" do
          get :tool_management
          response.should render_template("tool_management")
        end
      end
    end

    context "user is a standard user" do
      let(:current_user) {Factory.create(:user, :role => "user")}
      before(:each) do
        session[:user_id] = current_user.id
      end
  
      describe "index" do
        before(:each) do
          controller.stub_chain(:base_filtered_scope ,:includes, :order).and_return([tool])
        end
  
        it "should assign @tools" do
          get :index
          assigns[:tools].should == [tool]
        end
        it "should render the index page" do
          get :index
          response.should render_template("index")
        end
      end
  
      describe "bourreau_select" do
        let(:real_tool) {Factory.create(:tool, :user_id => current_user.id )}
  
        it "should render empty text if current_value is empty" do
          get(:bourreau_select, {'current_value' => ""})
          response.body.should be_empty
        end
  
        it "should render bourreau_select" do
          get(:bourreau_select,{'current_value' => real_tool.id.to_s})
          response.should render_template("tools/_bourreau_select")
        end 
        
        it "should display error text if go in rescue" do
          get(:bourreau_select, {'current_value' => "abc"})
          response.body.should =~ /No Execution Servers/
        end
      end
  
      describe "edit" do
  
        it "should redirect to error page" do
          get(:edit, {"id" => "1"})
          response.code.should == '401'
        end
      end
  
      describe "create" do
       
        it "should redirect to error page" do
          post(:create, :tool => {:name => "name"})
          response.code.should == '401'
        end
      
      end
  
      describe "update" do
                
        it "should redirect to error page" do
          put :update, :id => "1"
          response.code.should == '401'
        end
      end
  
      describe "destroy" do
        
        it "should redirect to error page" do
          delete :destroy, :id => "1"
          response.code.should == '401'
        end
      end
  
      describe "tool_managment" do
  
        it "should redirect to error page" do
          get :tool_management
          response.code.should == '401'
        end
      end
    end

    context "user is a site_manager" do
      let(:current_user) {Factory.create(:user, :role => "site_managerq")}
      before(:each) do
        session[:user_id] = current_user.id
      end
  
      describe "index" do
        before(:each) do
          controller.stub_chain(:base_filtered_scope ,:includes, :order).and_return([tool])
        end
  
        it "should assign @tools" do
          get :index
          assigns[:tools].should == [tool]
        end
        it "should render the index page" do
          get :index
          response.should render_template("index")
        end
      end
  
      describe "bourreau_select" do
        let(:real_tool) {Factory.create(:tool, :user_id => current_user.id )}
  
        it "should render empty text if current_value is empty" do
          get(:bourreau_select, {'current_value' => ""})
          response.body.should be_empty
        end
  
        it "should render bourreau_select" do
          get(:bourreau_select,{'current_value' => real_tool.id.to_s})
          response.should render_template("tools/_bourreau_select")
        end 
        
        it "should display error text if go in rescue" do
          get(:bourreau_select, {'current_value' => "abc"})
          response.body.should =~ /No Execution Servers/
        end
      end
  
      describe "edit" do
  
        it "should redirect to error page" do
          get(:edit, {"id" => "1"})
          response.code.should == '401'
        end
      end
  
      describe "create" do
       
        it "should redirect to error page" do
          post(:create, :tool => {:name => "name"})
          response.code.should == '401'
        end
      
      end
  
      describe "update" do
                
        it "should redirect to error page" do
          put :update, :id => "1"
          response.code.should == '401'
        end
      end
  
      describe "destroy" do
        
        it "should redirect to error page" do
          delete :destroy, :id => "1"
          response.code.should == '401'
        end
      end
  
      describe "tool_managment" do
  
        it "should redirect to error page" do
          get :tool_management
          response.code.should == '401'
        end
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