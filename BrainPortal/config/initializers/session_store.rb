
# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
CbrainRailsPortal::Application.config.session_store :active_record_store, {
    :key          => 'BrainPortalSession',
    :expire_after => 3.days,
    :cookie_only  => false,
  }

