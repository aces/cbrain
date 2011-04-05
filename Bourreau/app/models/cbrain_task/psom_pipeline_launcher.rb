
#
# CBRAIN Project
#
# ClusterTask Model PsomPipelineLauncher
#
# $Id$
#


# A subclass of ClusterTask to run a PSOM pipeline. Must be
# subclassed for specific pipelines.
class CbrainTask::PsomPipelineLauncher < ClusterTask

  Revision_info="$Id$"

  # Used internally by PsomPipelineLauncher to encapsulate the XML rendering
  # needed by the PSOM pipeline builder
  class PsomXmlEvaluator #:nodoc:

    Revision_info="$Id$"

    # Similar to the ERB:Util method for HTML, to allow escaping of XML text
    def xml_escape(s) #:nodoc:
      s.to_s.gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;").gsub(/'/,"&apos;")
    end
    alias x xml_escape #:nodoc:
  end

  # See CbrainTask.txt
  def setup #:nodoc:
    params       = self.params || {}

    subtasks = [] # declared at beginning so it's seen by the method's rescue clause cleanup.

    # Record code versions
    self.addlog_revinfo(CbrainTask::PsomPipelineLauncher)
    self.addlog_revinfo(self)

    # Sync input data
    fmri_study = FmriStudy.find(params[:interface_userfile_ids][0])
    fmri_study.sync_to_cache

    # -----------------------------------------------------------------
    # Create the XML input description for the particular PSOM pipeline
    # -----------------------------------------------------------------
    self.addlog("Building pipeline description")

    xml_template = self.get_psom_launcher_template_xml
    xml_erb      = ERB.new(xml_template,0,">")
    xml_erb.def_method(PsomXmlEvaluator, 'render(task, params, fmri_study)', "(PSOM XML for #{self.name})")
    begin
      xml_filled = PsomXmlEvaluator.new.render(self, params, fmri_study)
    rescue => ex
      self.addlog("Error building XML input file for pipeline builder.")
      self.addlog_exception(ex)
      return false
    end

    launcher_xml_file = self.name.underscore + ".xml"
    File.open(launcher_xml_file, "w") do |fh|
      fh.write xml_filled
    end

    pipe_desc_dir = self.pipeline_desc_dir
    safe_mkdir(pipe_desc_dir)
    return false unless self.build_pipeline(launcher_xml_file, pipe_desc_dir)

    # Detect situations of restarts (when params[:subtask_ids] already contains something).
    subtask_ids = params[:subtask_ids] || []
    if subtask_ids.size > 0 && self.run_number > 1
      orig_subtasks = CbrainTask.find_all_by_id(subtask_ids) rescue []
      if orig_subtasks.size == subtask_ids.size
        self.addlog("Skipping setup of subtasks, as we are restarting everything.")
        return true
      end
      self.addlog("Error trying to restart: it seems some of the subtasks we expected to find have ceased to exist.")
      return false
    end

    # -----------------------------------------------------------------
    # Read the XML pipeline description for the PSOM jobs
    # -----------------------------------------------------------------

    # IMPORTANT NOMENCLATURE NOTE: in this code,
    #  * the word 'job' is used to identify PSOM jobs
    #  * the word 'task' is used to identify CBRAIN tasks
   
    self.addlog("Creating subtasks")

    # Extract the list of jobs and index it
    pipeline_xml    = File.read("#{pipe_desc_dir}/pipeline.xml")
    pipeline_struct = Hash.from_xml(pipeline_xml)

    # Debug: create a DOT formated file of the job dependencies
    dotout = self.create_dot_graph(pipeline_struct);
    File.open("#{self.name.underscore}.dot","w") { |fh| fh.write(dotout) } # for debugging

    # For each job, build lists of 'follower' and 'predecessor' jobs
    # NOTE: cannot store these lists inside the job objects themselves, as it would confuse their to_s() renderers
    jobs                   = pipeline_struct['pipeline']['job']
    jobs                   = [ jobs ] unless jobs.is_a?(Array)
    jobs_by_id             = jobs.index_by { |job| job['id'] }
    job_id_to_successors   = {}
    job_id_to_predecessors = {}
    jobs.each do |job|
      job_id       = job['id']
      dependencies = (job['dependencies'] || {})['dependency'] || []
      dependencies = [ dependencies] unless dependencies.is_a?(Array)
      job_id_to_successors[job_id]   ||= []
      job_id_to_predecessors[job_id] ||= []
      dependencies.each do |depjobid|
        job_id_to_predecessors[job_id] << depjobid
        job_id_to_successors[depjobid] ||= []
        job_id_to_successors[depjobid] << job_id
      end
    end

    # -----------------------------------------------------------------
    # Create a topologically sorted array of jobs
    # -----------------------------------------------------------------

    # Identify the set of jobs that are 'starter' jobs (with no dependencies)
    jobs_queue   = jobs.select { |job| job_id = job['id'] ; job_id_to_predecessors[job_id].empty? }

    # Stuff updated while processing the jobs list
    ordered_jobs = [] # Our final list
    seen_job_ids = {} # Record what jobs we've seen
    max_postponing = 10000 # stupid counter to detect infinite loops
    job_id_to_level = {} # for pretty indentation of CbrainTasks

    # Main loop through our queue of jobs
    while jobs_queue.size > 0
      #puts_blue "QUEUE: " + show_ids(jobs_queue)

      # Current job is extracted from head of processing queue
      job    = jobs_queue.shift
      job_id = job['id']
      next if seen_job_ids[job_id]

      # All predecessors must be ordered already. Otherwise, push back at end of queue
      predecessor_ids = job_id_to_predecessors[job_id] || []
      unless predecessor_ids.all? { |pid| seen_job_ids[pid] }
         jobs_queue << job # postpone it
         max_postponing -= 1
         cb_error "It seems we have a job cycle in the pipeline description." if max_postponing < 1
         next
      end

      # Identify a 'level' for the job, which is 1 more than the highest level among predecessors
      max_level = 1
      predecessor_ids.each do |pid|
         prec_level = job_id_to_level[pid] || 1
         max_level = prec_level + 1 if prec_level >= max_level # >= important, not simply >
      end
      job_id_to_level[job_id] = max_level

      # Push the job on the 'ordered' list, mark it as processed.
      ordered_jobs << job
      seen_job_ids[job_id] = true

      # Push all unprocessed followers on the queue
      follower_ids = job_id_to_successors[job_id] || []
      follower_ids.each do |follower_id|
        next if seen_job_ids[follower_id]
        follower = jobs_by_id[follower_id]
        cb_error "Internal error: can't find follower job with ID '#{follower_id}' ?!?" unless follower
        jobs_queue.reject! { |j| j['id'] == follower_id }
        jobs_queue << follower
      end

    end

    # Check that all jobs in the initial list were reached and ordered.
    missing_jobs = jobs.select { |job| ! seen_job_ids[job['id']] }
    cb_error "The graph of jobs seems to contain #{missing_jobs.size} jobs unconnected to the rest of the graph?!?" if missing_jobs.size > 0

    # -----------------------------------------------------------------
    # Create one Cbrain::PsomSubtask for each job
    # -----------------------------------------------------------------

    # At this point, ordered_jobs has them all ordered topologically
    pipe_run_dir = self.pipeline_run_dir
    safe_mkdir(pipe_run_dir)
    job_id_to_task = {}
    ordered_jobs.each_with_index do |job,job_idx|
      job_id    = job['id']
      job_name  = job['name']
      job_file  = job['job_file']
      job_level = job_id_to_level[job_id]

      # Create the task associated to one PSOM job
      subtask = CbrainTask::PsomSubtask.new(
        :status         => "Standby", # important! Will be changed to New only of everything OK, at the end.
        :user_id        => self.user_id,
        :group_id       => self.group_id,
        :bourreau_id    => self.bourreau_id,
        :tool_config_id => self.tool_config_id, # TODO this is not exactly right
        :description    => job_name + "\n\n" + fmri_study.name,
        :launch_time    => self.launch_time,
        :run_number     => self.run_number,
        :share_wd_tid   => self.id,
        :rank           => job_idx + 1,
        :level          => job_level,
        :params         => {
          :psom_job_id            => job_id,
          :psom_job_name          => job_name,
          :psom_pipe_desc_subdir  => pipe_desc_dir,  # rel path of file to run is psom_pipe_desc_subdir/job_file
          :psom_job_script        => job_file,
          :psom_job_run_subdir    => pipe_run_dir,    # work directory for subtask; shared by all, here.
          :psom_main_pipeline_tid => self.id # same as share_wd_tid
        }
      )
      job_id_to_task[job_id] = subtask

      #puts_blue "#{show_ids(job_id)} -> Creating subtasks"
      #puts_cyan " => PREC: #{show_ids(job_id_to_predecessors[job_id] || [])}"
      #puts_cyan " => SUCC: #{show_ids(job_id_to_successors[job_id] || [])}"

      # Add prerequisites so that it only runs when its
      # predecessors are done
      predecessor_ids = job_id_to_predecessors[job_id] || []
      predecessor_ids.each do |predecessor_id|
        prec_task = job_id_to_task[predecessor_id]
        cb_error "Can't find predecessor task '#{predecessor_id}' for '#{job_id}' ?!?" unless prec_task
        subtask.add_prerequisites_for_setup(prec_task)
      end

      # Save it, in STANDBY state!
      # The tasks will be activated in cluster_commands().
      subtask.save!
      subtasks << subtask
    end

    # Add prerequisites such that OUR post processing occurs only when
    # all subtasks are done.
    subtasks.each { |subtask| self.add_prerequisites_for_post_processing(subtask) }

    # Record all the IDs of the subtasks.
    params[:subtask_ids] = subtasks.map &:id

    self.save

    return true

  # Handle errors
  rescue => ex
    # Cleanup subtasks
    subtasks.each do |badtask|
      badtask.destroy rescue true
    end
    raise ex
  end

  # See CbrainTask.txt
  def cluster_commands #:nodoc:
    params       = self.params || {}

    subtask_ids  = params[:subtask_ids] || []

    # Activate all the standby subtasks now
    subtasks = CbrainTask.find_all_by_id(subtask_ids)
    if subtasks.size != subtask_ids.size
      cb_error "It seems some of the subtasks we are looking for have ceased to exist."
    end
    subtasks.each do |subtask|
      next unless subtask.status == "Standby" # in recover situations, they can be in other states.
      subtask.status = "New"
      subtask.save!
    end

    return nil # no cluster commands to run
  end
  
  # See CbrainTask.txt
  def save_results #:nodoc:
    params       = self.params
    cb_error "The PSOM pipeline coder did not implement save_results in his subclass!?!"
  end

  # Subclasses of PsomPipelineLauncher need to define
  # this method to return a XML document as a string
  # potentially with ERB (embedded ruby components).
  # The ERB code can user three local variables that
  # will be defined when the XML is being rendered:
  #
  #  * task       is self
  #  * params     is task.params
  #  * fmri_study is the input study object
  #
  # The default behavior is actually to try to find a file
  # in the subdirectory named 'models/xml_templates_psom'
  # that has the same name as the class (underscored)
  # with a .xml.erb extension.
  def get_psom_launcher_template_xml
    plain_name = self.name.underscore
    base_name  = plain_name + ".xml.erb"
    full_path  = "#{RAILS_ROOT}/app/models/cbrain_task/xml_templates_psom/#{base_name}"
    if File.exists?(full_path)
      return File.read(full_path)
    end
    cb_error "No XML template '#{base_name}' for class #{self.name}."
  end

  # This method invokes whatever program is needed
  # to read the +xml_file+ supplied in argument and create
  # in +pipeline_dir+ the necessary PSOM files to describe
  # the subtasks involved in the pipeline.
  #
  # The default is to invoke the program that has the same
  # name as the class (underscored), providing it with the path
  # to the +xml_file+ and the +pipeline_dir+.
  def build_pipeline(xml_file, pipeline_dir)
    prog    = self.name.underscore
    # Note that 'psom_octave_wrapper.sh' is supplied in vendor/cbrain/bin on the Bourreau side
    command = "psom_octave_wrapper.sh $PSOM_ROOT/#{prog} #{xml_file} #{pipeline_dir}"
    self.addlog("Pipeline builder: #{command}")
    outs    = tool_config_system(command)
    stdout  = outs[0] ; stderr = outs[1]
    unless stdout.index("***Success***")
      self.addlog("Pipeline builder failed.")
      self.addlog("STDOUT:\n#{stdout}\n") unless stdout.blank?
      self.addlog("STDERR:\n#{stderr}\n") unless stderr.blank?
      return false
    end
    true
  end



  #--------------------------------------------------------------------
  # Overridable filesystem names
  #--------------------------------------------------------------------

  # Returns the basename for the subdirectory where the PSOM
  # pipeline description will be built.
  def pipeline_desc_dir #:nodoc:
    "pipeline_description"
  end

  # Returns the basename for the subdirectory where the PSOM
  # pipeline will actually be run.
  def pipeline_run_dir #:nodoc:
    "psom_pipeline"
  end



  #--------------------------------------------------------------------
  # Restart support methods
  #--------------------------------------------------------------------

  # Chronological behavior:
  #  - all subtasks reset here at Standby
  #  - setup() called:
  #     - pipeline description will be rebuilt in it
  #     - subtasks are NOT recreated in it (skipped by code that detect restarts)
  #  - cluster_command() called:
  #     - subtasks changed to New
  def restart_at_setup #:nodoc:
    params       = self.params || {}

    subtask_ids  = params[:subtask_ids] || []
    subtasks     = CbrainTask.find_all_by_id_and_status(subtask_ids, "Completed") rescue []
    if subtasks.size != subtask_ids.size
      self.addlog("Cannot restart: cannot find all Completed subtasks we expected.")
      return false
    end

    subtasks.each do |subtask|
      subtask.status = 'Standby'
      subtask.save
    end

    true
  end

  # Chronological behavior:
  #  - all subtasks reset here at Standby
  #  - cluster_command() called:
  #     - subtasks changed to New
  def restart_at_cluster #:nodoc:
    self.restart_at_setup # same logic
  end

  def restart_at_post_processing #:nodoc:
    false # Needs to be enabled in subclasses, if needed.
  end



  #--------------------------------------------------------------------
  # Error recovery support methods
  #--------------------------------------------------------------------

  def recover_from_setup_failure #:nodoc:
    params       = self.params || {}

    self.addlog("Cleaning up as part of recovery preparations")

    subtask_ids  = params[:subtask_ids] || []
    subtasks     = CbrainTask.find_all_by_id(subtask_ids) rescue []
    subtasks.each do |subtask|
      subtask.destroy rescue true
    end
    
    pipe_run_dir  = self.pipeline_run_dir
    pipe_desc_dir = self.pipeline_desc_dir
    FileUtils.remove_dir(pipe_run_dir,  true) rescue true
    FileUtils.remove_dir(pipe_desc_dir, true) rescue true

    params[:subtask_ids] = []
    self.prerequisites = {}
    true
  end

  def recover_from_cluster_failure #:nodoc:
    params       = self.params || {}

    self.addlog("Preparing to recover failed subtasks")

    subtask_ids  = params[:subtask_ids] || []
    subtasks     = CbrainTask.find_all_by_id(subtask_ids) rescue []
    subtasks.each do |subtask|
      subtask.recover
      subtask.save
    end
    true
  end

  def recover_from_post_processing_failure #:nodoc:
    false # Needs to be enabled in subclasses, if needed.
  end



  #--------------------------------------------------------------------
  # Debug support code.
  #--------------------------------------------------------------------

  # Debug topological sort; pass it an ID, an array of IDs,
  # an object that responds to ['id'] or an array of such objects.
  # Colorized the shortened IDs.
  def show_ids(idlist) #:nodoc:
     idlist = [ idlist ] unless idlist.is_a?(Array)
     res = ""
     idlist.each do |j|
       ji = j.is_a?(String) ? j : j['id']
       p1 = ji[0,2]; p2 = ji[2,2]; name = p1+p2;
       v1 = 0; v2 = 0
       p1.each_byte { |x| v1 += x }
       p2.each_byte { |x| v2 += x }
       c1 = v1 % 8
       c2 = v2 % 8
       colname = "\e[3#{c1};4#{c2}m#{name}\e[0m"
       res += " " unless res.blank?
       res += colname
     end
     res
  end

  # Returns a graph of the PSOM jobs dependencies in DOT format
  def create_dot_graph(xml_hash) #:nodoc:
    jobs            = xml_hash['pipeline']['job']
    jobs            = [ jobs ] unless jobs.is_a?(Array)
    jobs_by_id      = jobs.index_by { |job| job['id'] }

    dotout = "digraph #{self.name} {\n"
    jobs.each do |job|
      job_id       = job['id']
      job_name     = job['name']
      dependencies = (job['dependencies'] || {})['dependency'] || []
      dependencies = [ dependencies] unless dependencies.is_a?(Array)
      dependencies.each do |prec_id|
        prec      = jobs_by_id[prec_id]
        prec_name = prec['name']
        dotout += "  #{prec_name} -> #{job_name};\n"
      end
    end
    dotout += "}\n"
    dotout
  end

end

