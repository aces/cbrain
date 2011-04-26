
#
# CbrainTask class loader code
#

1.times do # just starts a block so local variable don't pollute anything

  basename    = File.basename(__FILE__)
  if basename == 'cbrain_task_class_loader.rb' # usually, the symlink destination
    puts "Weird. Trying to load the loader?!?"
    break
  end

  myshorttype = RAILS_ROOT =~ /BrainPortal$/ ? "portal" : "bourreau"
  dirname     = File.dirname(__FILE__)
  model       = basename.sub(/.rb$/,"")
  bytype_code = "#{dirname}/#{model}/#{myshorttype}/#{model}.rb"
  common_code = "#{dirname}/#{model}/common/#{model}.rb"

  if ! CbrainTask.const_defined? model.classify
    #puts_blue "LOADING #{bytype_code}"
    require_dependency bytype_code if File.exists?(bytype_code)
    require_dependency common_code if File.exists?(common_code)
  end

end

