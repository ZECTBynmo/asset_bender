require 'set'
config = Rails.application.config

if config.hubspot.running_server_from_script and config.hubspot.preload_style_guide_bundle

    # If the style guide comes from the static archive
    if config.hubspot.static_dependency_names.include? 'style_guide'
        build_names = Set.new config.hubspot.dependencies_for.map { |host_project, deps|
            deps['style_guide']
        }.compact!

    # IF the style guide is getting served directly
    elsif config.hubspot.static_project_names.include? 'style_guide'
        build_names = ['static']
    end

    if build_names
        for build_name in build_names

            job1 = fork do
                require 'net/http'
                hubspot_config = Rails.application.config.hubspot
                sleep 1

                urls = [
                    "http://localhost:#{hubspot_config.port}/style_guide/#{build_name}/sass/style_guide_plus_layout.css",
                    "http://localhost:#{hubspot_config.port}/style_guide/#{build_name}/js/style_guide_plus_layout.js"
                ]

                print "\nPreloading the style guide bundle, might take a while the very first time (~15-30s) ..."

                for url in urls
                    result = Net::HTTP.get_response(URI.parse(url))
                end

                puts "\nFinished preloading"
            end

            Process.detach(job1)
        end
    end
end