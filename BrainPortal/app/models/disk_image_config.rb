class DiskImageConfig < ActiveRecord::Base

  belongs_to     :bourreau   
  belongs_to     :disk_image_bourreau 

  attr_accessible :bourreau_id, :disk_image_bourreau_id, :open_stack_disk_image_id

end
