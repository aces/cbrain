# Be sure to restart your server when you modify this file.

Rails.application.config.session_store :cookie_store,
  :key          => 'BrainPortal8_Session',
  :same_site    => :lax,
  :expire_after => 3.days
