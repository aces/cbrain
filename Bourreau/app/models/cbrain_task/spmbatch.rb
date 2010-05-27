
#
# CBRAIN Project
#
# CbrainTask model
#
# Original author: Mathieu Desrosiers
#
# $Id$
#



#A subclass of CbrainTask::ClusterTask to run bigseed.
class CbrainTask::Spmbatch < CbrainTask::ClusterTask

  Revision_info="$Id$"

  def setup #:nodoc:
     params = self.params 
     command_args = " "
     subjects = params[:subjects]
     name = subjects[:name]
     if subjects.has_key?(:exclude)
       self.addlog("Subjects: #{name} succesfully excluded") 
       return true  
     end
     
     self.addlog("Arguments for BigSeed: #{command_args}")
         
     self.addlog("Subjects: #{name}")
     collection_id = params[:collection_id]
     collection = Userfile.find(collection_id)
     unless collection
       self.addlog("Could not find active record entry for FileCollection '#{collection_id}'.")      
       return false
     end

     params[:data_provider_id] ||= collection.data_provider_id
     
     collection.sync_to_cache
     self.addlog("Study full path: #{collection.cache_full_path.to_s}")
     rootDir = File.join(collection.cache_full_path.to_s,name)
     self.addlog("Task root directory: #{rootDir}")
     
     File.symlink(rootDir,name)

     batch_names = []
     batchs_files = params[:batchs_files]
     batchs_files.each { |id , value|      
       batch = Userfile.find(value)
       batch.sync_to_cache
       batch_name = batch.cache_full_path.to_s
       batch_names.push(batch_name)
       self.addlog("Batch[#{id}] to process: #{batch_name}") 
       command_args += " #{batch_name}"     
     }
     
     command_args += " --doCleanUp " if subjects.has_key?(:doCleanUP)
     command_args += " --doFieldMap " if subjects.has_key?(:doFieldMap)            
     self.params[:command_args] = command_args  
     self.addlog("Full command arguments: #{command_args}")
     true
  end

  def cluster_commands #:nodoc:
    params       = self.params
    command_args    = params[:command_args]
    subjects = params[:subjects]
    name = subjects[:name]        
    command = "bigseed ./#{name}  #{command_args}"
    
    [
    "unset DISPLAY",
    "echo \"\";echo Showing ENVIRONMENT",
    "env | sort",
    "echo \"\";echo Starting SpmBatch",
    "echo Command: #{command}",
    "#{command}"
    ]
  
  end
  
  def save_results #:nodoc:
    params       = self.params
    user_id      = self.user_id
    subjects = params[:subjects]
    name = subjects[:name]
    save_all = ! params[:save_all]
    self.addlog("saveall=#{params[:save_all].inspect}")

    collection_id = params[:collection_id]
    collection = Userfile.find(collection_id)
    source_userfile = FileCollection.find(collection_id)
    
    self.addlog("Study full path: #{collection.cache_full_path.to_s}")
    rootDir = File.join(collection.cache_full_path.to_s,name)
    self.addlog("Task root directory: #{rootDir}")

    data_provider_id = params[:data_provider_id]  
    self.addlog("user_id= #{user_id}")
    self.addlog("data_provider_id= #{data_provider_id}")
    self.addlog("group_id= #{source_userfile.group_id}")    
    spmbatchresult = FileCollection.new(
        :name             => name,
        :user_id          => user_id,
        :group_id         => source_userfile.group_id,
        :data_provider_id => data_provider_id,
        :task             => "SpmBatch"
    )
    
    self.addlog("spmbatchresult = #{spmbatchresult}")
    self.addlog("spmbatchresult = #{spmbatchresult.name}")
    # Main location for output files
    Dir.mkdir("spmbatch_out",0700)           
    Dir.mkdir("spmbatch_out/#{name}",0700)
    Dir.mkdir("spmbatch_out/#{name}/scripts",0700)
    FileUtils.cp(Dir.glob("#{rootDir}/*.m"),"spmbatch_out/#{name}/scripts") rescue true
    FileUtils.cp(Dir.glob("#{rootDir}/*.ps"),"spmbatch_out/#{name}/scripts") rescue true
    FileUtils.cp_r("#{rootDir}/spmbatch_log_dir","spmbatch_out/#{name}") rescue true
    FileUtils.cp("#{rootDir}/spmbatch_master.log", "spmbatch_out/#{name}/spmbatch_log_dir/spmbatch_master.log") rescue true  
    
    self.addlog("Just results and logs will be saved")
    #find where the results have been save
    #this function assume that there is a directory call spmbatch_log_dir
    result_file = "#{rootDir}/spmLog/#{name}_resultat_dir.txt"
    self.addlog("Here result file: #{result_file}")
    if File.exist?(result_file) && !File.zero?(result_file)
      self.addlog("Opening file: #{result_file}")
      File.open(result_file,'r').each_line do |resultat_dir|
        self.addlog("archive results in directory: #{resultat_dir}")
        self.addlog("Create an archive with results in directory: #{resultat_dir}")          
        FileUtils.cp_r("#{resultat_dir}","spmbatch_out/#{name}") rescue true    
      end
    end
    if save_all
      self.addlog("Everything should be save")
    end
    if spmbatchresult.save
      spmbatchresult.cache_copy_from_local_file("spmbatch_out/#{name}")
      spmbatchresult.addlog_context(self,"Created by task '#{self.bname_tid}' from '#{source_userfile.name}'")
      spmbatchresult.move_to_child_of(source_userfile)
      self.addlog("Saved new spmBatch result file #{spmbatchresult.name}.")
      return true
    else
      self.addlog("Could not save back result file '#{spmbatchresult.name}'.")
      return false
    end
    
    self.addlog("Have a nice day!")      
      
  end
end

