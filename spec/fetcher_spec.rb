require 'asset_bender_test'

describe AB::Fetcher do

  before(:each) do
    @df = AB::Fetcher.new({
      :domain => "somecrazydomain.net",
      :environment => :qa,
      :cache => false
    })

    @project1 = AB::Project.load_from_file fixture_path('project1')

    # @prod_df = AB::Fetcher.new({
    #   :domain => "somecrazydomain.net",
    #   :environment => :prod,
    #   :cache => false
    # })
  end

  context 'when a url for a build is created with a version range' do
    subject { @df.url_for_build_pointer 'project_foo', AB::Version.new('2.3.x') }
    it { should eq("http://somecrazydomain.net/project_foo/latest-version-2.3-qa") }
  end

  context 'when a url for a build is created with a special version string' do
    subject { @df.url_for_build_pointer 'project_foo', AB::Version.new('edge') }
    it { should eq("http://somecrazydomain.net/project_foo/edge-qa") }
  end

  context 'when a url for a build is created with a fixed version' do
    it 'should' do
      expect { @df.url_for_build_pointer 'project_foo', AB::Version.new('1.2.3') }.to raise_error
    end
  end

  context 'when a url for a build is created with a version range with force_production' do
    subject { @df.url_for_build_pointer 'project_foo', AB::Version.new('2.3.x'), { :force_production => true } }
    it { should eq("http://somecrazydomain.net/project_foo/latest-version-2.3") }
  end

  context 'when the strip_leading_slash helper method is called on a string with no slash' do
    it "shouldn't strip it" do
      @df.strip_leading_slash("foo/bar").should eq("foo/bar")
    end
  end

  context 'when the strip_leading_slash helper method is called on a string with a slash' do
    it 'should strip it' do
      @df.strip_leading_slash("/foo/bar").should eq("foo/bar")
    end
  end

  context 'when an asset url is built' do
    subject { @df.build_asset_url "project_bar", "v1.2.3", "/some/important/img.gif" }
    it { should eq("http://somecrazydomain.net/project_bar/v1.2.3/some/important/img.gif") }
  end

  # context 'when the last build is fetched' do
  #   subject { @df.fetch_last_successful_build @project1 }
  #   it { should eq("v2.1.7") }
  # end

  # context 'when the cache is turned on' do
  #   subject do
  #     AB::Fetcher.new({
  #       :domain => "somecrazydomain.net",
  #       :cache => true   
  #     })
  #   end

  #   it { should_not raise_error }
  # end

end


    # def build_hash_filename
    # def denormalized_dependencies_filename

    # def fetch_last_successful_build(project_name, version_to_build, options = nil)
    # def fetch_last_production_build(project_name, version_to_build)
    # def fetch_last_build_hash(project_name, version_to_build)
    # def fetch_last_builds_dependencies(project_name, version_to_build)
    # def fetch_last_build_infomation(project_name, version_to_build)
