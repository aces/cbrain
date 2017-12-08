
# Be sure to restart your server when you modify this file.

ActiveSupport::Inflector.inflections(:en) do |inflect|

  # CBRAIN Added inflections
  inflect.irregular 'bourreau', 'bourreaux'
  inflect.irregular 'status', 'status'
end

