require 'socket'



class ApplicationController < ActionController::Base
  include HubspotHelpers
  
  protect_from_forgery
  before_filter :prepare

  # Override these in your own static app
  @@app_name = "testing..."
  @@title = @@screen_id = @@screen_action = nil

  def initialize
    # All of the static projects specified in .hubspot/config that have a view/ directory
    view_paths = Rails.application.config.hubspot.static_project_view_paths

    # Add all of those view paths to this controller's 
    view_paths.each do |path|
      append_view_path path
    end
    # append_view_path ActionView::PathSet.new(Array.wrap(view_paths))
  end

  # Render the template located at *path
  def base
    render :template => params[:path]
  end

  def currently_served_projects
    Rails.application.config.hubspot.static_project_names || Set.new
  end

  def dependencies_for(project_name)
    Rails.application.config.hubspot.dependencies_for[project_name] || {}
  end

  def non_served_dependencies_for(project_name)
    served_projects = currently_served_projects
    deps = dependencies_for project_name

    # We only want to munge build names for non-served dependencies
    # (surrounded with Hash to be backwards compatible with 1.8.7)
    Hash[ deps.select { |dep, version| !served_projects.include? dep } ]
  end

  # Render all the html needed to include the bundle specified by *path
  def bundle_for
    path = params[:path]
    debug = params[:verb] == "expanded"
    host_project_name = Rails.application.config.hubspot.aliased_project_name params[:from]

    # Annoying. Different environments react differently to having a slash at the front or not
    path = "/#{path}" if not debug and not path.starts_with? '/'

    # We only want to munge build names for non-served dependencies
    non_served_deps = non_served_dependencies_for host_project_name

    # Munge build names before manifest resolution
    if host_project_name
      non_served_deps.each do |dep, build_name|
        path.gsub! "#{dep}/static/", "#{dep}/#{build_name}/"
      end
    end

    if is_js_bundle path
      result = render :inline => "<%= javascript_include_tag('#{path}', :debug => #{debug} ) %>"
    elsif is_css_bundle path
      result = render :inline => "<%= stylesheet_link_tag('#{path}', :debug => #{debug} ) %>"
    else
      raise "Specified bundle: \"#{path}\" isn't a valid js or css bundle."
    end

    # Munge build names after manifest resolution
    if host_project_name
      result = result.map do |str|
        non_served_deps.each do |dep, build_name|
          str.gsub! "#{dep}/static/", "#{dep}/#{build_name}/"
        end

        str
      end
    else
      result
    end
  end

  # Returns the build name for a project
  def build_for
    project_name = params[:project]
    host_project_name = Rails.application.config.hubspot.aliased_project_name params[:from]

    deps = dependencies_for host_project_name
    non_served_deps = non_served_dependencies_for host_project_name

    if project_name != host_project_name and not deps.include? project_name
      raise "Unknown project (#{project_name}). Is is not a dependency of '#{host_project_name}'. " +
            "You should make sure it is in #{host_project_name}'s static_conf.json"
    end

    # If this project is a dependency, then return that build, else return 'static' becasue that project is "actively" served
    render :text => non_served_deps[project_name] || 'static'
  end

  def debug_test_handler
    render :text => ""
  end

  def prepare
    @title = @@title || "#{@@app_name} | HubSpot" || "HubSpot"

    @server_host_name = get_server_host_name
    @hubspot_env = get_hubspot_env

    @screen_id = @@screen_id
    @screen_action = @@screen_action

    @old_static_domain = Rails.application.config.hubspot.old_static_domain
  end

  def get_server_host_name
    Socket.gethostname
  end

  def get_hubspot_env
    if Rails.env.development? then "local" else Rails.env end
  end

end


# class HubSpotCustomViewsResolver < ::ActionView::FileSystemResolver

#   def initialize path
#     super(path)
#   end

#   def find_templates(name, prefix, partial, details)
#     puts "\nname:  #{name.inspect}\n\n"
#     puts "\nprefix:  #{prefix.inspect}\n\n"
#     puts "\npartial:  #{partial.inspect}\n\n"
#     puts "\ndetails:  #{details.inspect}\n\n"

#     # find_templates(name, ancestor_prefix, partial, details)
#     super
#   end
# end