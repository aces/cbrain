class AddDataladToDataProvider < ActiveRecord::Migration[5.0]
  def change
    add_column    :data_providers, :datalad_repository_url, :string
    add_column    :data_providers, :datalad_relative_path,  :string
  end
end
