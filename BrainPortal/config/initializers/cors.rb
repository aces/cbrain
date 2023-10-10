
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    # This is a dummy configuration.
    # Adjust as needed.
    origins 'https://example.com:8888'
    resource '/doesnotexist',
      :headers => :any,
      :methods => [:get]
  end
end

