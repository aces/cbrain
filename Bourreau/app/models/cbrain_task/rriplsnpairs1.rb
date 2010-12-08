                                #
# CBRAIN Project
#
# ClusterTask Model Rriplsnpairs1
#
# Original author:
#
# $Id: cluster_task_model.rb 1220 2010-07-06 20:01:01Z prioux $
#
# A subclass of ClusterTask to run Rriplsnpairs1.
class CbrainTask::Rriplsnpairs1 < ClusterTask
	
  include RestartableTask # This task is naturally restartable
  include RecoverableTask # This task is naturally recoverable

  Revision_info="$Id: cluster_task_model.rb 1220 2010-07-06 20:01:01Z prioux $"

###########################
# See CbrainTask.txt
  def setup #:nodoc:
    params       = self.params
    
    user_id = self.user_id
    self.addlog("Setting up PLS-NPAIRS task.")
    
    files   = params[:interface_userfile_ids]
    file_id = files[0]
    file = Userfile.find(file_id)   
    
    params[:data_provider_id] = file.data_provider_id if params[:data_provider_id].blank?
    true
  
  end
##########################3
  # See CbrainTask.txt
  def cluster_commands #:nodoc:
	  
  params       = self.params
  npairsPLS_command = ''
  npairsPLS_command2 = ''
  args = ''
  args_datamat = ''
  file_basename = ''
  datamat_basename = ''
	# *****************
	# Npairs Block CS
	#params[:nb_cs_commandline_chunk]
	#params[:nb_cs_BRAIN_MASK_FILE]
	#params[:nb_cs_DATA_FILES]
	#params[:nb_cs_ONSET_FILES]
	#params[:nb_cs_FILE_BASENAME]
	
	
	if !params[:nb_cs_commandline_chunk].blank? && !params[:nb_cs_DATA_FILES].blank?
		
		if !params[:nb_cs_BRAIN_MASK_FILE].blank?
			brain_mask_file_new = ''
			brainmaskfile_id = params[:nb_cs_BRAIN_MASK_FILE].to_s.rstrip
			brainmaskfile = Userfile.find(brainmaskfile_id)
			brainmaskfile.sync_to_cache
			brainmaskfile_cachefullpath = brainmaskfile.cache_full_path.to_s
			brainmaskfile_name=brainmaskfile.name
			safe_symlink(brainmaskfile_cachefullpath,brainmaskfile_name)
			brain_mask_file_new = '"' + brainmaskfile_cachefullpath + '"' 
			
			args += ' -USE_MASK_FILE "true" '
			args += " -BRAIN_MASK_FILE  #{brain_mask_file_new}  "
			self.addlog("Line 63 brainmask #{args}" )
		else
		args += ' -USE_MASK_FILE "false" '
		end
		
		if !params[:nb_cs_ONSET_FILES].blank?
			onset_files_new = ""
			onset_files_squeeze= params[:nb_cs_ONSET_FILES].to_s.squeeze(" ").rstrip
			onset_files = onset_files_squeeze.split
			onset_files_size=onset_files.size
			onsetfiles_paths = ""

			x = 0
			while x < onset_files_size do
				onsetfile_id = onset_files[x]
				onsetfile = Userfile.find(onsetfile_id)
				onsetfile.sync_to_cache
				onsetfile_cachefullpath = onsetfile.cache_full_path.to_s
				onsetfile_name=onsetfile.name
				safe_symlink(onsetfile_cachefullpath,onsetfile_name)	
				onset_files_new =  onset_files_new + '"' + onsetfile_cachefullpath + '"  '
				x = x+1
			end
			args +=" -ONSET_FILES #{onset_files_new} "
			self.addlog("Line onsetfiles #{args}" )
		end
		
		if !params[:nb_cs_DATA_FILES].blank?
				
			#### DATA_FILES & DATA_PATH ####
			data_files_new = ""
			data_paths_new = ""
			data_files_squeeze= params[:nb_cs_DATA_FILES].to_s.squeeze(" ").rstrip
			data_files = data_files_squeeze.split
			data_files_size=data_files.size

			x = 0
			while x < data_files_size do
				datafile_id = data_files[x]
				datafile = Userfile.find(datafile_id)
				datafile.sync_to_cache
				datafile_cachefullpath = datafile.cache_full_path.to_s
				safe_symlink(datafile_cachefullpath,datafile.name)
	 	
				if datafile.is_a?(FileCollection)
					file_collection_name = datafile.name
					data_paths_new = data_paths_new +  '"'  + datafile_cachefullpath +  '" '
					datacollection_files_num = datafile.num_files
					datacollection_files = datafile.list_files.map(&:name)
					j = 1
					while j < datacollection_files_num do 
						datacollection_file_name = File.basename(datacollection_files[j])
						data_files_new =  data_files_new + '"' + datacollection_file_name + '",'	
						j = j + 2
					end
				else
					singledatafile_name = datafile.name
					singledatafile_path= datafile_cachefullpath.chomp(singledatafile_name) 
					data_paths_new = data_paths_new + '"' + singledatafile_path + '" '
					data_files_new =  data_files_new + '"' + singledatafile_name + '",'
				end
				x = x+1
				data_files_new=data_files_new.rstrip.chop + "   "
			end
				args += "-DATA_FILES #{data_files_new} "  
				args += "-DATA_PATHS #{data_paths_new} " 
			self.addlog("Line 128 data files  and paths #{args}" )	
		end	

		if !params[:nb_cs_commandline_chunk].blank?
			
			session_file_dir = Dir.getwd	
			args += ' -SESSION_FILE_DIR " ' 
			args += "#{session_file_dir}"
			args += '" '
			args += params[:nb_cs_commandline_chunk]
			
			self.addlog("Line  137:  session file dir: #{args}")
			
		end	
	npairsPLS_command = "/usr/local/npairs_pls/npairs_createSessionProfile #{args} "
	npairsPLS_command1 = "echo \"\";echo Running Npairs Create Session Profile ......"
	npairsPLS_command2 = "echo \"\";echo Running Npairs Create Session Profile ......"	
	# *****************
	# Npairs & PLS Event CS & PLS Block
	elsif !params[:ne_cs_commandline_chunk].blank? && !params[:ne_cs_DATA_FILES].blank?
	#params[:ne_cs_commandline_chunk]
	#params[:ne_cs_BRAIN_MASK_FILE]
	#params[:ne_cs_DATA_FILES]
	#params[:ne_cs_ONSET_FILES]
	#params[:ne_cs_FILE_BASENAME]
	#params[:ne_cd_DATAMAT_BASENAME]
	#params[:ne_cs_ANALYSIS_TYPE]
	
	

		if !params[:ne_cs_BRAIN_MASK_FILE].blank?
			brain_mask_file_new = ''
			brainmaskfile_id = params[:ne_cs_BRAIN_MASK_FILE].to_s.rstrip
			brainmaskfile = Userfile.find(brainmaskfile_id)
			brainmaskfile.sync_to_cache
			brainmaskfile_cachefullpath = brainmaskfile.cache_full_path.to_s
			brainmaskfile_name=brainmaskfile.name
			safe_symlink(brainmaskfile_cachefullpath,brainmaskfile_name)
			brain_mask_file_new = '"' + brainmaskfile_cachefullpath + '"' 
			
			args += ' -USE_MASK_FILE "true" '
			args += " -BRAIN_MASK_FILE  #{brain_mask_file_new}  "
			self.addlog("Line 169 brainmask #{args}" )
		else
			args += ' -USE_MASK_FILE "false" '
		end
	
		if !params[:ne_cs_ONSET_FILES].blank?
			onset_files_new = ""
			onset_files_squeeze= params[:ne_cs_ONSET_FILES].to_s.squeeze(" ").rstrip
			onset_files = onset_files_squeeze.split
			onset_files_size=onset_files.size
			onsetfiles_paths = ""

			x = 0
			while x < onset_files_size do
				onsetfile_id = onset_files[x]
				onsetfile = Userfile.find(onsetfile_id)
				onsetfile.sync_to_cache
				onsetfile_cachefullpath = onsetfile.cache_full_path.to_s
				onsetfile_name=onsetfile.name
				safe_symlink(onsetfile_cachefullpath,onsetfile_name)	
				onset_files_new =  onset_files_new + '"' + onsetfile_cachefullpath + '"  '
				x = x+1
			end
			args +=" -ONSET_FILES #{onset_files_new} "
			self.addlog("Line onsetfiles #{args}" )
		end
		
		if !params[:ne_cs_DATA_FILES].blank?
		#### DATA_FILES & DATA_PATH ####
			data_files_new = ""
			data_paths_new = ""
			data_files_squeeze= params[:ne_cs_DATA_FILES].to_s.squeeze(" ").rstrip
			data_files = data_files_squeeze.split
			data_files_size=data_files.size

			x = 0
			while x < data_files_size do
				datafile_id = data_files[x]
				datafile = Userfile.find(datafile_id)
				datafile.sync_to_cache
				datafile_cachefullpath = datafile.cache_full_path.to_s
				safe_symlink(datafile_cachefullpath,datafile.name)
	 	
				if datafile.is_a?(FileCollection)
					file_collection_name = datafile.name
					data_paths_new = data_paths_new +  '"'  + datafile_cachefullpath +  '" '
					datacollection_files_num = datafile.num_files
					datacollection_files = datafile.list_files.map(&:name)
					j = 1
					while j < datacollection_files_num do 
						datacollection_file_name = File.basename(datacollection_files[j])
						data_files_new =  data_files_new + '"' + datacollection_file_name + '",'	
						j = j + 2
					end
				else
					singledatafile_name = datafile.name
					singledatafile_path= datafile_cachefullpath.chomp(singledatafile_name) 
					data_paths_new = data_paths_new + '"' + singledatafile_path + '" '
					data_files_new =  data_files_new + '"' + singledatafile_name + '",'
				end
				x = x+1
				data_files_new=data_files_new.rstrip.chop + "   "
			end
				args += "-DATA_FILES #{data_files_new} "  
				args += "-DATA_PATHS #{data_paths_new} " 
			self.addlog("Line 236 data files  and paths #{args}" )	
		end
		if !params[:ne_cs_commandline_chunk].blank?
			
			session_file_dir = Dir.getwd	
			args += ' -SESSION_FILE_DIR " ' 
			args += "#{session_file_dir}"
			args += '" '
			args += params[:ne_cs_commandline_chunk]
			
			self.addlog("Line  239:  session file dir: #{args}")
			
		end
		
		if !params[:ne_cd_commandline_chunk].blank?
			
			args_datamat += params[:ne_cd_commandline_chunk]
			self.addlog("Line  251:  session file dir: #{args_datamat}")
			
		end
		
	self.addlog("Line 262 analysis type params[:ne_cs_ANALYSIS_TYPE]" )
	
	analysis_type=params[:ne_cs_ANALYSIS_TYPE]
	if analysis_type == "enpairs"
	npairsPLS_command = "/usr/local/npairs_pls/npairs_createSessionProfile #{args}  -BLOCK false"
	npairsPLS_command1 = "echo \"\";echo Running Create Session Profile for NPairs Event Related Analysis ......"
	npairsPLS_command2 = "/usr/local/npairs_pls/npairs_createDatamat #{args_datamat} "
	elsif 	analysis_type == "epls"
	npairsPLS_command = "/usr/local/npairs_pls/pls_createSessionProfile #{args} -BLOCK false"
	npairsPLS_command1 = "echo \"\";echo Running Create Session Profile for Event-Related PLS Analysis ......"
	npairsPLS_command2 = "/usr/local/npairs_pls/pls_createDatamat #{args_datamat} "
	else
	npairsPLS_command = "/usr/local/npairs_pls/pls_createSessionProfile #{args} -BLOCK true"
	npairsPLS_command1 = "echo \"\";echo Running Create Session Profile for Block PLS Analysis ......"
	npairsPLS_command2 = "/usr/local/npairs_pls/pls_createDatamat #{args_datamat} "	
	end
	
	# *****************
	# Npairs Setup
	elsif !params[:n_sa_commandline_chunk].blank? && !params[:n_sa_SESSION_FILES1].blank? && !params[:n_sa_SESSION_FILES2].blank?
	#params[:n_sa_SESSION_FILES1]
	#params[:n_sa_SESSION_FILES2]
	#params[:n_sa_EVD_FILE_PREFIX]
	#params[:n_sa_SPLITS_INFO_FILENAME]
	#params[:n_sa_FILE_BASENAME]
	#params[:n_sa_commandline_chunk]
	
	
	# ######################################
	#SESSION_FILES PROCESSING
	#######################################
	n_sa_SESSION_FILES1_parameter_new = ""
	n_sa_SESSION_FILES2_parameter_new = ""
	n_sa_SESSION_FILES1_files = params[:n_sa_SESSION_FILES1].to_s.squeeze(" ").rstrip.split
	n_sa_SESSION_FILES2_files = params[:n_sa_SESSION_FILES2].to_s.squeeze(" ").rstrip.split
	n_sa_SESSION_FILES1_size = n_sa_SESSION_FILES1_files.size
	n_sa_SESSION_FILES2_size = n_sa_SESSION_FILES2_files.size


	x = 0
	while x < n_sa_SESSION_FILES1_size do
		n_sa_SESSION_FILES1_id = n_sa_SESSION_FILES1_files[x]
		n_sa_SESSION_FILES1 = Userfile.find(n_sa_SESSION_FILES1_id)
		n_sa_SESSION_FILES1.sync_to_cache
		n_sa_SESSION_FILES1_cachefullpath = n_sa_SESSION_FILES1.cache_full_path.to_s
		n_sa_SESSION_FILES1_name=n_sa_SESSION_FILES1.name
		#self.addlog(onsetfile_name)
    		safe_symlink(n_sa_SESSION_FILES1_cachefullpath,n_sa_SESSION_FILES1_name)	
		n_sa_SESSION_FILES1_parameter_new =  n_sa_SESSION_FILES1_parameter_new + '"' + n_sa_SESSION_FILES1_cachefullpath + '",'
	 x = x+1
	end
	n_sa_SESSION_FILES1_parameter_new = n_sa_SESSION_FILES1_parameter_new.rstrip.chop 
 
 
	x = 0
	while x < n_sa_SESSION_FILES2_size do
		n_sa_SESSION_FILES2_id = n_sa_SESSION_FILES2_files[x]
		n_sa_SESSION_FILES2 = Userfile.find(n_sa_SESSION_FILES2_id)
		n_sa_SESSION_FILES2.sync_to_cache
		n_sa_SESSION_FILES2_cachefullpath = n_sa_SESSION_FILES2.cache_full_path.to_s
		n_sa_SESSION_FILES2_name=n_sa_SESSION_FILES2.name
		#self.addlog(onsetfile_name)
    		safe_symlink(n_sa_SESSION_FILES2_cachefullpath,n_sa_SESSION_FILES2_name)	
		n_sa_SESSION_FILES2_parameter_new =  n_sa_SESSION_FILES2_parameter_new + '"' + n_sa_SESSION_FILES2_cachefullpath + '",'
	 x = x+1
	end
	n_sa_SESSION_FILES2_parameter_new = n_sa_SESSION_FILES2_parameter_new.rstrip.chop 
	args += "-SESSION_FILES  #{n_sa_SESSION_FILES1_parameter_new}    #{n_sa_SESSION_FILES2_parameter_new}  " 
	

	#################
	## EVD FILE PREFIX
	#################
	n_sa_EVD_FILE_PREFIX_parameter_new =""
	n_sa_EVD_FILE_PREFIX_prefix=""
	if ! params[:n_sa_EVD_FILE_PREFIX].blank?
		n_sa_EVD_FILE_PREFIX_files = params[:n_sa_EVD_FILE_PREFIX].to_s.squeeze(" ").rstrip.split
		n_sa_EVD_FILE_PREFIX_size= n_sa_EVD_FILE_PREFIX_files.size 

		x = 0
		while x < n_sa_EVD_FILE_PREFIX_size do
			n_sa_EVD_FILE_PREFIX_id = n_sa_EVD_FILE_PREFIX_files[x]
			n_sa_EVD_FILE_PREFIX = Userfile.find(n_sa_EVD_FILE_PREFIX_id)
			n_sa_EVD_FILE_PREFIX.sync_to_cache
			n_sa_EVD_FILE_PREFIX_cachefullpath = n_sa_EVD_FILE_PREFIX.cache_full_path.to_s
			n_sa_EVD_FILE_PREFIX_name=n_sa_EVD_FILE_PREFIX.name
			safe_symlink(n_sa_EVD_FILE_PREFIX_cachefullpath,n_sa_EVD_FILE_PREFIX_name)	
			if n_sa_EVD_FILE_PREFIX_name.include? ".EVD."
				substrindex = n_sa_EVD_FILE_PREFIX_name.index('.EVD.')
				n_sa_EVD_FILE_PREFIX_prefix = "#{n_sa_EVD_FILE_PREFIX_name[0..substrindex-1]}"
			end
		
		x = x+1
		end
		current_dir=Dir.getwd
		n_sa_EVD_FILE_PREFIX_parameter_new = "#{current_dir}/#{n_sa_EVD_FILE_PREFIX_prefix}"
		
		args +="-EVD_FILE_PREFIX #{n_sa_EVD_FILE_PREFIX_parameter_new}  "
		self.addlog("342 line: #{n_sa_EVD_FILE_PREFIX_parameter_new}")
	end



	#################
	## SPLIT INFO FILE NAME
	#################
	n_sa_SPLITS_INFO_FILENAME_parameter_new =""
	if ! params[:n_sa_SPLITS_INFO_FILENAME].blank?
		self.addlog("277 line :  #{params[:n_sa_SPLITS_INFO_FILENAME].to_s.rstrip}")
		n_sa_SPLITS_INFO_FILENAME_id = params[:n_sa_SPLITS_INFO_FILENAME].to_s.rstrip
		n_sa_SPLITS_INFO_FILENAME_original = Userfile.find(n_sa_SPLITS_INFO_FILENAME_id)
		n_sa_SPLITS_INFO_FILENAME_original.sync_to_cache
		n_sa_SPLITS_INFO_FILENAME_original_cachefullpath = n_sa_SPLITS_INFO_FILENAME_original.cache_full_path.to_s
		n_sa_SPLITS_INFO_FILENAME_parameter_new = n_sa_SPLITS_INFO_FILENAME_original_cachefullpath
		self.addlog("358 line :  #{n_sa_SPLITS_INFO_FILENAME_parameter_new}")
		args +="-SPLITS_INFO_FILENAME #{n_sa_SPLITS_INFO_FILENAME_parameter_new}  " 
	end
	
	if !params[:n_sa_commandline_chunk].blank?
			
			args += params[:n_sa_commandline_chunk]
			self.addlog("Line  365:  session file dir: #{args_datamat}")
	end

	npairsPLS_command = "/usr/local/npairs_pls/npairs_setupAnalysis #{args} "
	npairsPLS_command1 = "echo \"\";echo Running Npairs Setup Analysis ......"
	npairsPLS_command2 = "echo \"\";echo Running Npairs Setup Analysis ......"
	# *****************
	# Npairs Run
	elsif !params[:n_ra_DATA_FILES].blank?
	#params[:n_ra_xxxxM]
	#params[:n_ra_DATA_FILES]
		n_ra_FILES_id = params[:n_ra_DATA_FILES].to_s.rstrip
		n_ra_FILES_original = Userfile.find(n_ra_FILES_id)
		n_ra_FILES_original.sync_to_cache
		n_ra_FILES_original_cachefullpath = n_ra_FILES_original.cache_full_path.to_s
		n_ra_FILES_parameter_new = n_ra_FILES_original_cachefullpath
		self.addlog("383 line :  #{n_ra_FILES_parameter_new}")
		
		args ="  -#{params[:n_ra_xxxxM]} " 	
		args +="   #{n_ra_FILES_parameter_new}" 
	npairsPLS_command = "/usr/local/npairs_pls/npairs_runAnalysis #{args} "
	npairsPLS_command1 = "echo \"\";echo Running Npairs Analysis ......"
	npairsPLS_command2 = "echo \"\";echo Running Npairs Analysis ......"
	
	#****************
	# PLS Setup
	elsif !params[:p_sa_commandline_chunk].blank? && !params[:p_sa_SESSION_FILES1].blank? && !params[:p_sa_SESSION_FILES2].blank?
	#params[:p_sa_SESSION_FILES1]
	#params[:p_sa_SESSION_FILES2]
	#params[:p_sa_contrastdata]
	#params[:p_sa_behaviordata]
	#params[:p_sa_commandline_chunk]
	#params[:p_sa_FILE_BASENAME]
	
	#SESSION_FILES PROCESSING
	#######################################
	p_sa_SESSION_FILES1_parameter_new = ""
	p_sa_SESSION_FILES2_parameter_new = ""
	p_sa_SESSION_FILES1_files = params[:p_sa_SESSION_FILES1].to_s.squeeze(" ").rstrip.split
	p_sa_SESSION_FILES2_files = params[:p_sa_SESSION_FILES2].to_s.squeeze(" ").rstrip.split
	p_sa_SESSION_FILES1_size = p_sa_SESSION_FILES1_files.size
	p_sa_SESSION_FILES2_size = p_sa_SESSION_FILES2_files.size
	
	x = 0
	while x < p_sa_SESSION_FILES1_size do
		p_sa_SESSION_FILES1_id = p_sa_SESSION_FILES1_files[x]
		p_sa_SESSION_FILES1 = Userfile.find(p_sa_SESSION_FILES1_id)
		p_sa_SESSION_FILES1.sync_to_cache
		p_sa_SESSION_FILES1_cachefullpath = p_sa_SESSION_FILES1.cache_full_path.to_s
		p_sa_SESSION_FILES1_name=p_sa_SESSION_FILES1.name
		#self.addlog(onsetfile_name)
    		safe_symlink(p_sa_SESSION_FILES1_cachefullpath,p_sa_SESSION_FILES1_name)	
		p_sa_SESSION_FILES1_parameter_new =  p_sa_SESSION_FILES1_parameter_new + '"' + p_sa_SESSION_FILES1_cachefullpath + '",'
	 x = x+1
	end
	p_sa_SESSION_FILES1_parameter_new = p_sa_SESSION_FILES1_parameter_new.rstrip.chop 
 
 
	x = 0
	while x < p_sa_SESSION_FILES2_size do
		p_sa_SESSION_FILES2_id = p_sa_SESSION_FILES2_files[x]
		p_sa_SESSION_FILES2 = Userfile.find(p_sa_SESSION_FILES2_id)
		p_sa_SESSION_FILES2.sync_to_cache
		p_sa_SESSION_FILES2_cachefullpath = p_sa_SESSION_FILES2.cache_full_path.to_s
		p_sa_SESSION_FILES2_name=p_sa_SESSION_FILES2.name
		#self.addlog(onsetfile_name)
    		safe_symlink(p_sa_SESSION_FILES2_cachefullpath,p_sa_SESSION_FILES2_name)	
		p_sa_SESSION_FILES2_parameter_new =  p_sa_SESSION_FILES2_parameter_new + '"' + p_sa_SESSION_FILES2_cachefullpath + '",'
	 x = x+1
	end
	p_sa_SESSION_FILES2_parameter_new = p_sa_SESSION_FILES2_parameter_new.rstrip.chop 
	args += "-SESSION_FILES  #{p_sa_SESSION_FILES1_parameter_new}    #{p_sa_SESSION_FILES2_parameter_new}  " 
	
	if !params[:p_sa_contrastdata].blank?
			contrast_data_file_new = ''
			contrastdata_file_id = params[:p_sa_contrastdata].to_s.rstrip
			contrastdata_file = Userfile.find(contrastdata_file_id)
			contrastdata_file.sync_to_cache
			contrastdata_file_cachefullpath = contrastdata_file.cache_full_path.to_s
			contrastdata_file_name=contrastdata_file.name
			safe_symlink(contrastdata_file_cachefullpath,contrastdata_file_name)
			contrast_data_file_new = '"' + contrastdata_file_cachefullpath + '"' 
			
		
			args += " -CONTRAST_FILENAME  #{contrast_data_file_new}  "
			self.addlog("Line 450 contrast file #{args}" )
	elsif !params[:p_sa_behaviordata].blank?
			behavior_data_file_new = ''
			behaviordata_file_id = params[:p_sa_contrastdata].to_s.rstrip
			behaviordata_file = Userfile.find(behaviordata_file_id)
			behaviordata_file.sync_to_cache
			behaviordata_file_cachefullpath = behaviordata_file.cache_full_path.to_s
			behaviordata_file_name=behaviordata_file.name
			safe_symlink(behaviordata_file_cachefullpath,behaviordata_file_name)
			behavior_data_file_new = '"' + behaviordata_file_cachefullpath + '"' 
			
		
			args += " BEHAVIOR_FILENAME  #{behavior_data_file_new}  "
			self.addlog("Line 464 behavior file #{args}" )
			
		end
	

	if !params[:p_sa_commandline_chunk].blank?
			
			args += params[:p_sa_commandline_chunk]
			self.addlog("Line 401:  session file dir: #{args}")
	end

	npairsPLS_command = "/usr/local/npairs_pls/pls_setupAnalysis #{args} "
	npairsPLS_command1 = "echo \"\";echo Running PLS Setup Analysis ......"
	npairsPLS_command2 = "echo \"\";echo Running PLS Setup Analysis ......"
	#*************
	#PLS Run
	elsif !params[:p_ra_DATA_FILES].blank?
	#params[:p_ra_xxxxM]
	#params[:p_ra_DATA_FILES]	
	#*****************	
		p_ra_FILES_id = params[:p_ra_DATA_FILES].to_s.rstrip
		p_ra_FILES_original = Userfile.find(p_ra_FILES_id)
		p_ra_FILES_original.sync_to_cache
		p_ra_FILES_original_cachefullpath = p_ra_FILES_original.cache_full_path.to_s
		p_ra_FILES_parameter_new = p_ra_FILES_original_cachefullpath
		self.addlog("410 line :  #{p_ra_FILES_parameter_new}")
	
		args ="  -#{params[:p_ra_xxxxM]} " 	
		args +="   #{p_ra_FILES_parameter_new}" 
		npairsPLS_command = "/usr/local/npairs_pls/pls_runAnalysis #{args} "
		npairsPLS_command1 = "echo \"\";echo Running PLS Analysis ......"
		npairsPLS_command2 = "echo \"\";echo Running PLS Analysis ......"
	end
	
	self.addlog("Line 472 Npairs command #{npairsPLS_command}")
	[
		"echo \"\";echo Command : #{npairsPLS_command1}",
		"echo \"\";echo Command : #{npairsPLS_command}",
		"echo \"\";echo Command : #{npairsPLS_command2}",
		"#{npairsPLS_command}",
		"#{npairsPLS_command2}",
		"echo \"\";echo Done! "
		
	]
  end

#############################
  # See CbrainTask.txt
  def save_results #:nodoc:
    params       = self.params
    
    
     file_basename = 'matlab file'
     datamat_basename = 'datamat file'
     time = Time.new
     
	if !params[:nb_cs_commandline_chunk].blank? && !params[:nb_cs_DATA_FILES].blank?
		file_basename = params[:nb_cs_FILE_BASENAME]
	elsif !params[:ne_cs_commandline_chunk].blank? && !params[:ne_cs_DATA_FILES].blank?
		file_basename = params[:ne_cs_FILE_BASENAME]
		datamat_basename = params[:ne_cd_DATAMAT_BASENAME]
	elsif !params[:n_sa_commandline_chunk].blank?
		file_basename = params[:n_sa_FILE_BASENAME]
	elsif !params[:p_sa_commandline_chunk].blank? 
		file_basename = params[:p_sa_FILE_BASENAME]
	elsif !params[:n_ra_DATA_FILES].blank?
		file_basename = "Npairs_ra_Results_MDhms_#{time.month}_#{time.day}_#{time.hour}_#{time.min}_#{time.sec}"
	elsif !params[:p_ra_DATA_FILES].blank?   
		file_basename = "Pls_ra_Results_MDhms_#{time.month}_#{time.day}_#{time.hour}_#{time.min}_#{time.sec}"
	end
	
	files   = params[:interface_userfile_ids]
	file_id = files[0]
	file  = Userfile.find(file_id)
	user_id     = self.user_id 
	data_provider_id = params[:data_provider_id]  
	rootDir=Dir.getwd

	 if !params[:n_ra_DATA_FILES].blank? || !params[:p_ra_DATA_FILES].blank?
		plsnpairsresult = safe_userfile_find_or_new(FileCollection,
		:name             => file_basename,
		:user_id          => user_id,
		:group_id         => group_id,
		:data_provider_id => data_provider_id,
		:task             => "Rriplsnpairs1"
		)
		unless plsnpairsresult.save
			cb_error "Line 241 Could not save back collection file '#{plsnpairsresult.name}'."
		end

		safe_mkdir("NpairsPls_Analysis",0700) 
		npairspls_out = "NpairsPls_Analysis"    
		FileUtils.cp(Dir.glob("#{rootDir}/*.*"),"NpairsPls_Analysis") rescue true
		plsnpairsresult.cache_copy_from_local_file(npairspls_out)
	
	else
		self.addlog("user_id= #{user_id}")
		self.addlog("data_provider_id= #{data_provider_id}")
		self.addlog("group_id= #{file.group_id}")  
		self.addlog("file_basename= #{file_basename}")  
		savedir = "savedir"	
		npairspls_result = safe_userfile_find_or_new(SingleFile,
			:name             => file_basename,
			:user_id          => user_id,
			:group_id         => file.group_id,
			:data_provider_id => data_provider_id,
			:task             => "Rriplsnpairs1"
		)
		
		if npairspls_result.save
			npairspls_result.cache_copy_from_local_file("#{file_basename}")
			self.addlog("Saved file #{file_basename}")
			resultfilesavedfullpath = npairspls_result.cache_full_path.to_s
			savedir = resultfilesavedfullpath.chomp("#{file_basename}")
			self.addlog("467 #{savedir}")
		
		else
			self.addlog("Line 600 Could not save back result file '#{file_basename}'.")

		end
	end

	if  !params[:ne_cd_DATAMAT_BASENAME].blank?  
		self.addlog("Line 513 #{params[:ne_cd_DATAMAT_BASENAME].to_s}")
		datamat_basename = "#{datamat_basename}_fMRIdatamat.mat"
		npairspls_result1 = safe_userfile_find_or_new(SingleFile,
			:name             => datamat_basename,
			:user_id          => user_id,
			:group_id         => file.group_id,
			:data_provider_id => data_provider_id,
			:task             => "Rriplsnpairs1"
		)
		self.addlog("line 523 datamat_basename= #{datamat_basename}")      		
		if npairspls_result1.save
			npairspls_result1.cache_copy_from_local_file("#{datamat_basename}")
			self.addlog("Saved file #{datamat_basename}")
			datamatsavedfullpath = npairspls_result1.cache_full_path.to_s
			File.symlink("#{datamatsavedfullpath}", "#{savedir}#{datamat_basename}")
			self.addlog("Created symlink #{datamatsavedfullpath} as #{savedir}#{datamat_basename}")
		else
			self.addlog("Line 624 Could not save back result file '#{datamat_basename}'.")	
		end

	end
return true

end
end
