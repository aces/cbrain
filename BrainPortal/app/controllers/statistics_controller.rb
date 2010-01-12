class StatisticsController < ApplicationController
  # GET /statistics
  # GET /statistics.xml
  def index
    @stats_user = Statistic.find(:all, :conditions => {:user_id => current_user.id})
    @task_names = @stats_user.map { |stat| stat.task_name } | []
    @stats_total_user = Statistic.total_task_user(current_user.id)
    @bourreaux = Bourreau.find(:all)
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @statistics }
    end
  end

  # GET /statistics/1
  # GET /statistics/1.xml
  def show
    @bourreau = Bourreau.find(params[:id])
    @stats_bourreau = Statistic.find(:all, :conditions => {:bourreau_id => @bourreau.id})
    @task_names = @stats_bourreau.map { |stat| stat.task_name } | []
    @task_stats = Statistic.find(:all, :conditions => {:bourreau_id => @bourreau.id, :task_name => @task_names})
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @statistic }
    end
  end
  
end
