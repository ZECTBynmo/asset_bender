require "asset_bender_test"

VersionUtils = AssetBender::VersionUtils

describe 'VersionUtils' do
  before(:each) do
    @project_names = [
        'project',
        'project1',
        'some-thing',
        'some_thing',
        '4thebest',
        'project'
    ]
  end

  it 'should create replacment regexes that work' do
    assorted_version_placeholders = [
        'static',
        'version',
        'v',
        'v1',
        'version-here',
        '__version__'
    ]

    @project_names.each do |project_name|
      assorted_version_placeholders.each do |placeholder|
        re = VersionUtils::project_replacement_regex project_name
        match = re.match "#{project_name}/#{placeholder}/"

        match.should_not be_nil
        match[1].should eq(placeholder)
      end
    end
  end

  it 'should create project & version subpaths correctly' do
    semvers = [
      SemVer.new(1, 2, 3),
      SemVer.new(0, 20, 7, 'beta'),
    ]

    output = [
      "#{@project_names[0]}/v1.2.3/",
      "#{@project_names[1]}/v0.20.7-beta/",
    ]

    @project_names[0...2].zip(semvers, output) do |args|
      project_name, semver, output = args
      VersionUtils::project_with_version_path(project_name, semver).should eq(output)
    end
  end

  it 'should munge project versions inline' do
    sources = [
      "url(/project1/v/bla.gif)\nurl(/project1/static/bla.gif)",
      "url(/project1/version/bla.gif)\nurl(/project1/__version__/bla.gif)",
    ]

    semvers = [
      SemVer.new(1, 2, 3),
      SemVer.new(0, 20, 7, 'beta'),
    ]

    output = [
      "url(/project1/v1.2.3/bla.gif)\nurl(/project1/v1.2.3/bla.gif)",
      "url(/project1/v0.20.7-beta/bla.gif)\nurl(/project1/v0.20.7-beta/bla.gif)",
    ]

    sources.zip(semvers, output) do |args|
      source, semver, output = args
      VersionUtils::replace_project_versions_in(source, 'project1', semver).should eq(output)
    end
  end

  it 'should munge multiple projects versions inline' do
    source = "url(/project1/v/bla.gif)\nurl(/other_proj/static/bla.gif)"
    output = "url(/project1/v1.2.3/bla.gif)\nurl(/other_proj/v2.10.6/bla.gif)"

    versions_by_project = {
      :project1 => SemVer.new(1, 2, 3),
      :other_proj => SemVer.new(2, 10, 6),
    }

    VersionUtils::replace_all_projects_versions_in(source, versions_by_project)
  end

  context 'when extracting strings from paths' do
    names = ['project1', 'another_proj', 'b3st.thing-ev4r']

    it 'should find the string in a subpath' do
      VersionUtils::look_for_string_in_path("some/path/project1/version/lib.js", names).should eq("project1")
    end

    it 'should find the string in a full path' do
      VersionUtils::look_for_string_in_path("/some/path/another_proj/v/coffee/app.coffee", names).should eq("another_proj")
    end

    it 'should find the string in a file:// path' do
      VersionUtils::look_for_string_in_path("file://some/path/another_proj/v/coffee/app.coffee", names).should eq("another_proj")
    end

    it 'should find the string in a http:// path' do
      VersionUtils::look_for_string_in_path("http://some/path/b3st.thing-ev4r/v1.3.4/sass/styles.css", names).should eq("b3st.thing-ev4r")
    end

    it 'should return nil if none of the strings are found' do
      VersionUtils::look_for_string_in_path("/some/path/non-project/version/lib.js", names).should be_nil
    end

    it 'should only find the last (rightmost) match' do
      VersionUtils::look_for_string_in_path("/some/project1/path/another_proj/version/lib.js", names).should eq("another_proj")
    end
  end

  context 'when extracting strings and versions from paths' do
    names = ['dep1', 'another_dep', 'b3st.dep-ev4r']

    it 'should find the string and version in a subpath' do
      VersionUtils::look_for_string_preceding_version_in_path("some/path/dep1/v1.2.3/lib.js", names).should eq(["dep1", AssetBender::Version.new("v1.2.3")])
    end

    it 'should find the string and version at the end' do
      VersionUtils::look_for_string_preceding_version_in_path("some/path/another_dep/v10.0.97/", names).should eq(["another_dep", AssetBender::Version.new("v10.0.97")])
    end
  end

end
