HubspotStaticDaemon::Application.routes.draw do
  # The "bundle" API. Returns all the css/js in a bundle as HTML (eg. a bunch of <link> or <script> tags)
  match '/bundle-:verb/*path', :controller => 'application', :action => 'bundle_for'
  match '/bundle/*path', :controller => 'application', :action => 'bundle_for'

  # The "build version" API. Returns the current build name for a specific project.
  match '/builds/:project', :controller => 'application', :action => 'build_for', :constraints => { :project =>/[^\/]+/ }

  # Map all of /<depname_name>/static-.*/ to Sprockets for every valid dependency in ~/.hubspot/static-archive/
  all_projects_and_dependency_names = Rails.application.config.hubspot.static_dependency_names + Rails.application.config.hubspot.static_project_names
  all_projects_and_dependency_names.each do |project_name|
    match "/#{project_name}/:build_name/*path" => Rails.application.assets, :constraints => { :build_name => /static(-.*)?/ }
  end

  # Map all of /<project_name>/static to Sprockets for every single project configured in ~/.hubspot/config.yaml
  Rails.application.config.hubspot.static_project_names.each do |project_name|
    match "/#{project_name}/static/*path" => Rails.application.assets
  end

  # Map all other requests to views (templates defined in <project_name>/view/*)
  match '/*path', :controller => 'application', :action => 'base'
end
