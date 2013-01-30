require "asset_bender_test"

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
      AB::Version.is_valid_version(str).should be_true
      AB::Version.new(str).should eq(semver)
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
      parsed_semver = AB::Version.new(str)
      parsed_semver.should eq(semver)
      parsed_semver.is_wildcard.should be_true
    end
  end


  it 'should parse special version strings' do
    versions = [
      'recommended',
      'current',
      'edge'
    ]

    version_vals = [
      'recommended',
      'recommended',
      'edge'
    ]

    versions.zip(version_vals).each do |(str, val)|
      parsed_version = AB::Version.new(str)
      parsed_version.to_s.should eq(val)
      parsed_version.is_wildcard.should be_true
    end
  end

end
