class RemoveNhEmailDeliveryOptionsFromNhContactInfo < ActiveRecord::Migration[5.0]
  def change
    remove_column :remote_resources, :nh_email_delivery_options, :text, :after => :nh_system_from_email
  end
end
