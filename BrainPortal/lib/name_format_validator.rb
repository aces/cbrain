class NameFormatValidator < ActiveModel::EachValidator
  def validate_each(object, attribute, value)
    unless value.blank? || value =~ /^[a-zA-Z0-9][ \w\~\!\@\#\%\^\*\-\+\=\:\;\,\.\?]*$/
      object.errors[attribute] << (options[:message] || "contains invalid characters") 
    end
  end
end