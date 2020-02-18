# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
Rails.application.config.assets.precompile += %w( jquery.js jquery-ui.js jquery.form jquery_ujs chosen_1.8.7.jquery.min )

Rails.application.config.assets.precompile += %w( tablesorter_themes/blue/style.css )
Rails.application.config.assets.precompile += %w( cbrain.css )
Rails.application.config.assets.precompile += %w( dynamic-table.css )
Rails.application.config.assets.precompile += %w( jquery-ui.css )
Rails.application.config.assets.precompile += %w( userfiles.css )
Rails.application.config.assets.precompile += %w( chosen_1.8.7.scss )
Rails.application.config.assets.precompile += %w( neurohub.scss )
Rails.application.config.assets.precompile += %w( noc.css )
Rails.application.config.assets.precompile += %w( boutiques.css )

# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
# Rails.application.config.assets.precompile += %w( search.js )
