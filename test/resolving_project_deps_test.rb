require 'asset_bender_test'

AB::Config.load_all_base_config_files

class ResolvingDepsTest < Test::Unit::TestCase
  def test_resolve
    AB::ProjectsManager.setup [fixture_path('project1')]
    AB::DependenciesManager.setup fixture_path('faux-local-archive')

    @fetcher = AB::Fetcher.new({
      :domain => "file://#{fixture_path('faux_s3_bucket')}"
    })

    p1 = AB::ProjectsManager.get_project 'project1'
    resolved_deps = p1.resolved_dependencies({ :fetcher => @fetcher })

    print "\n", "resolved_deps:  #{resolved_deps.inspect}", "\n\n"
  end
end