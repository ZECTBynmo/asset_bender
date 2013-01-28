require "asset_bender_test"

AB = AssetBender
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
    assorted_verson_placeholders = [
        'static',
        'version',
        'v',
        'v1',
        'version-here',
        '__version__'
    ]

    @project_names.each do |project_name|
      assorted_verson_placeholders.each do |placeholder|
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
      VersionUtils::project_with_version(project_name, semver).should eq(output)
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

end
