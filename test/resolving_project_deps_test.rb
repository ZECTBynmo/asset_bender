require 'asset_bender_test'

AB::Config.load_all_base_config_files

class ResolvingDepsTest < Test::Unit::TestCase
  def setup
    @fetcher = AB::Fetcher.new({
      :domain => "file://#{fixture_path('faux_s3_bucket')}"
    })
  end

  def test_resolve
    project_paths = [fixture_path('project1')]

    AB::ProjectsManager.setup project_paths
    AB::DependenciesManager.setup fixture_path('faux-local-archive')

    p1 = AB::ProjectsManager.get_project 'project1'
    resolved_deps = p1.resolved_dependencies({ :fetcher => @fetcher })

    assert_equal p1.dependencies_by_name.length, resolved_deps.length

    p1.dependencies_by_name.each do |dep_name, version|
      resolved_dep = resolved_deps.select {|dep| dep.name == dep_name.to_s}[0]
      assert_not_nil resolved_dep
      assert resolved_dep.version.is_fixed?
    end
  end

  def test_resolve_recursive
    project_paths = [fixture_path('project2')]

    AB::ProjectsManager.setup project_paths
    AB::DependenciesManager.setup fixture_path('faux-local-archive')

    p2 = AB::ProjectsManager.get_project 'project2'
    resolved_deps = p2.resolved_dependencies({ :fetcher => @fetcher })

    assert_equal p2.dependencies_by_name.length, resolved_deps.length

    assert_equal 1, resolved_deps[0].resolved_dependencies.length
    assert_equal "proj_foo", resolved_deps[0].resolved_dependencies[0].name

    assert_equal 1, resolved_deps[0].resolved_dependencies[0].resolved_dependencies.length
    assert_equal "proj_bar", resolved_deps[0].resolved_dependencies[0].resolved_dependencies[0].name
  end
end