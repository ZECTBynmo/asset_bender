require 'asset_bender_test'
require 'json'

AB = AssetBender

describe 'an AssetBender project' do

  it 'loads a component.json file from the project root' do
    proj = AB::Project.load_from_file fixture_path('project1')
    component_json = JSON::parse File.read fixture_path('project1/component.json')

    proj.name.should eq(component_json['name'])
    proj.description.should eq(component_json['description'])

    proj.version.to_s.should eq(component_json['version'])
    proj.recommended_version.to_s.should eq(component_json['recommended_version'])

    proj.dependency_names.should eq(component_json['dependencies'].keys)

    proj.dependency_map.each do |dep, version|
      version.should_not be_nil
      version.format(AB::Version::FORMAT).to_s.should eq(component_json['dependencies'][dep])
    end
  end

end