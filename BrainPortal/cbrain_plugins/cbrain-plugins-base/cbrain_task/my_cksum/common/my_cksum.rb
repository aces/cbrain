
# Model code common to the Bourreau and Portal side for MyCksum.
class CbrainTask::MyCksum

  # Write utility methods that are useful for your task model
  # both on the portal and bourreau side here.

  def self.compare_versions(v1,v2)
    v1.to_s <=> v2.to_s  # very dummy: we just compare the strings
  end

end

