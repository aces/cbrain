
# TMP PATCH PLACEHOLDER DURING DEVELOPMENT

class BoutiquesTask::NewMultiBoutiquesDemo < BoutiquesClusterTask

  def boutiques_descriptor
    @_desc ||= ::BoutiquesSupport::BoutiquesDescriptor.new(
      JSON.parse(
        File.read(
          CBRAIN::Plugins_Dir + "/cbrain-plugins-base/boutiques_descriptors/new_multi_boutiques_demo.json"
        )
      )
    )
  end

end
