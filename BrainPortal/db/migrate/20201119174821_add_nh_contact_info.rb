class AddNhContactInfo < ActiveRecord::Migration[5.0]
  def change
    # Existing cols:
    #  - support_email
    #  - system_from_email
    # Now we add these four in order:
    add_column :remote_resources, :email_delivery_options,    :text  , :after => :system_from_email
    add_column :remote_resources, :nh_support_email,          :string, :after => :email_delivery_options
    add_column :remote_resources, :nh_system_from_email,      :string, :after => :nh_support_email
    add_column :remote_resources, :nh_email_delivery_options, :text  , :after => :nh_system_from_email

    add_column :remote_resources, :nh_site_url_prefix,        :string, :after => :site_url_prefix
  end
end
