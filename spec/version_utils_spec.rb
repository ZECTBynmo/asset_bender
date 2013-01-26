require "asset_bender_test"

AB = AssetBender
VersionUtils = AssetBender::VersionUtils

describe 'VersionUtils' do
  it 'should validate correct version strings' do
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

    versions.each do |version|
      VersionUtils::is_valid_version(version).should be_true
    end
  end

  it 'should create replacment regexes that work' do
    project_names = [
        'project',
        'project1',
        'some-thing',
        'some_thing',
        '4thebest',
        'project'
    ]

    assorted_verson_placeholders = [
        'static',
        'version',
        'v',
        'v1',
        'version-here',
        '__version__'
    ]

    project_names.each do |project_name|
      assorted_verson_placeholders.each do |placeholder|
        re = VersionUtils::project_replacement_regex project_name
        match = re.match "#{project_name}/#{placeholder}/"

        match.should_not be_nil
        match[1].should eq(placeholder)
      end
    end
  end

end
