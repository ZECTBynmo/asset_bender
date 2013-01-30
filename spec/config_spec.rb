require 'asset_bender_test'

AssetBender::Config.register_extendable_base_config('test_base', {
  :base_setting => "some setting",
  :shared_setting => 20,
  :a_shared_hash => {
    :of => {
      :yet_more_stuff => "that is still awesome"
    },
    :and_more => 42
  }
})

AssetBender::Config.register_extendable_base_config 'test_base2' do
  { 
    :another_base_setting => "some other setting"
  }
end

describe AB::Config do

  it 'should default to loading from the home directory' do
    AB::Config.filename.should eq(File.expand_path "~/.bender.yaml")
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

  it 'should merge with base settings' do
    config = AB::Config.load fixture_path "example-bender.yaml"

    config.a_shared_hash.of.other_stuff.should eq("that is awesome")
    config.a_shared_hash.of.yet_more_stuff.should eq("that is still awesome")
    config.a_shared_hash.and_more.should eq(42)
  end

  it 'can be exported as a hash' do
    config = AB::Config.load fixture_path "example-bender.yaml"
    
    config.to_hash.should eq({
      :base_setting=>"some setting", 
      :shared_setting=>10, 
      :a_shared_hash=>{
        :of=>{
          :yet_more_stuff=>"that is still awesome", 
          :other_stuff=>"that is awesome"
        }, 
        :and_more=>42
      }, 
      :my_setting=>"funtown", 
      :a_hash=>{
        :of=>{
          :stuff=>"that is awesome"
        }
      }
    })
  end

  it 'should extend multiple configs' do
    config = AB::Config.load fixture_path "example-bender-multiple-bases.yaml"

    config.extends.should be_nil
    config.base_setting.should eq("some setting")
    config.another_base_setting.should eq("some other setting")
  end

  it 'should have a singleton global config' do
    AB::Config.instance.mysetting.should eq("timmfin")
    AB::Config.mysetting.should eq("timmfin")

    AB::Config.instance.new_setting = { :test => "yes" }
    AB::Config.new_setting.test.should eq("yes")
  end

  it "can't be instantiated manually, duped, or cloned" do
    AB::Config.new.should be_nil
    expect { AB::Config.dup }.to raise_error
    expect { AB::Config.clone }.to raise_error
  end
 
end