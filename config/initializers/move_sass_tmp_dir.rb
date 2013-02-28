if Rails.application.config.hubspot.custom_temp_dir
    Rails.application.config.sass.cache_location = File.join(Rails.application.config.hubspot.custom_temp_dir, "cache/sass")
end