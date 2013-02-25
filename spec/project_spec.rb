require 'asset_bender_test'
require 'json'

describe 'an AssetBender project' do

  it 'loads a component.json file from the project root' do
    proj = AB::LocalProject.load_from_file fixture_path('project1')
    component_json = JSON::parse File.read fixture_path('project1/component.json')

    proj.name.should eq(component_json['name'])
    proj.description.should eq(component_json['description'])

    proj.version.to_s.should eq(component_json['version'])
    proj.recommended_version.to_s.should eq(component_json['recommendedVersion'])

    proj.dependency_names.should eq(component_json['dependencies'].keys.map {|k| k.to_sym })

    proj.dependencies_by_name.each do |dep, version|
      version.should_not be_nil
      version.format(AB::Version::FORMAT).to_s.should eq(component_json['dependencies'][dep.to_s])
    end
  end

  it "throws an error if the component.json is invalid" do
    expect { AB::LocalProject.load_from_file fixture_path('broken_proj') }.to raise_error
  end

  it "has an alias if the parent folder doesn't match the name in the component.json" do
    proj = AB::LocalProject.load_from_file fixture_path('project2')
    proj.name.should eq("project2_real_name")
    proj.alias.should eq('project2')
  end

end