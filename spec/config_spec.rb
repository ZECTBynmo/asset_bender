require 'asset_bender_test'

AssetBender::Config.register_extendable_base_config('test_base', {
  :base_setting => "some setting",
  :shared_setting => 20
})

AssetBender::Config.register_extendable_base_config 'test_base2' do
  { 
    :another_base_setting => "some other setting"
  }
end

describe AB::Config do

  it 'should default to loading from the home directory' do
    AB::Config.base_filename.should eq(File.expand_path "~/.bender.yaml")
  end

  it 'should load from a yaml file' do
    config = AB::Config.load fixture_path "example-bender.yaml"
    config.my_setting.should eq("funtown")
  end

  it 'should have a base config to load from' do
    AB::Config.registered_base_configs.length.should be > 0
  end

  it 'should allow nested dot acccess' do
    config = AB::Config.load fixture_path "example-bender.yaml"
    config.a_hash.of.stuff.should eq("that is awesome")
  end

  it 'should extend a base config (via hash)' do
    config = AB::Config.load fixture_path "example-bender.yaml"
    config.extends.should be_nil
    config.base_setting.should eq("some setting")
  end

  it 'should overwrite base settings' do
    config = AB::Config.load fixture_path "example-bender.yaml"
    config.shared_setting.should eq(10)
  end


  it 'should extend multiple configs' do
    config = AB::Config.load fixture_path "example-bender-multiple-bases.yaml"

    config.extends.should be_nil
    config.base_setting.should eq("some setting")
    config.another_base_setting.should eq("some other setting")
  end
 
end