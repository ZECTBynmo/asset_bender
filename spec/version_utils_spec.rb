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

  it 'should parse and validate a few different version strings' do
    versions = [
      'v3.4.5',
      'v13.12.11',
      'v0.100.0-beta2',

      '3.4.5-prerelease',
      '13.12.11',
      '0.100.0',

      'static-3.4',
      'static-1.120',
    ]

    semvers = [
      SemVer.new(3, 4, 5),
      SemVer.new(13, 12, 11),
      SemVer.new(0, 100, 0, 'beta2'),

      SemVer.new(3, 4, 5, 'prerelease'),
      SemVer.new(13, 12, 11),
      SemVer.new(0, 100, 0),

      SemVer.new(0, 3, 4),
      SemVer.new(0, 1, 120),
    ]

    versions.zip(semvers).each do |(str, semver)|
      VersionUtils::is_valid_version(str).should be_true
      VersionUtils::parse_version(str).should eq(semver)
    end
  end

  it 'should parse wildcard version strings' do
    versions = [
      '3.4.x',
      '13.x.x',
      '0.100.x-beta2',
    ]

    semvers = [
      SemVerRange.new(3, 4, 'x'),
      SemVerRange.new(13, 'x', 'x'),
      SemVerRange.new(0, 100, 'x', 'beta2'),
    ]

    versions.zip(semvers).each do |(str, semver)|
      parsed_semver = VersionUtils::parse_version(str)
      parsed_semver.should eq(semver)
      parsed_semver.is_wildcard.should be_true
    end
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
