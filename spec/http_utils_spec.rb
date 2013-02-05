require 'asset_bender_test'

describe AB::HTTPUtils do
  before(:each) do
    @http_utils = AB::HTTPUtilsInstance.new
  end

  context 'when fetch_url is called' do
    it "should return the body of a successful request" do
      stub_request(:get, 'http://test.hubspot.com/something').to_return(:status => 200, :body => "The result body")
      @http_utils.fetch_url('http://test.hubspot.com/something').should eq("The result body")
    end

    it "should work with file:// urls" do
      @http_utils.fetch_url("file://#{fixture_path('local_file.txt')}").should eq("Local filesystem content")
    end

    it "should raise an exception if the url doesn\'t  exist (or returns non-200)" do
      stub_request(:get, 'http://text.hubspot.com/other').to_return(:status => 404)
      expect { @http_utils.fetch_url('http://text.hubspot.com/other') }.to raise_error
    end
  end

  context 'when fetch_url_with_retries is called' do
    it "should return the body of a successful request" do
      stub_request(:get, 'http://test.hubspot.com/something').to_return(:status => 200, :body => "The result body")
      @http_utils.fetch_url_with_retries('http://test.hubspot.com/something').should eq("The result body")
    end

    it "should work with file:// urls" do
      @http_utils.fetch_url_with_retries("file://#{fixture_path('local_file.txt')}").should eq("Local filesystem content")
    end

    it "should raise an exception if the url doesn\'t  exist (or returns non-200)" do
      stub_request(:get, 'http://text.hubspot.com/other').to_return(:status => 404)
      expect { @http_utils.fetch_url_with_retries('http://text.hubspot.com/other') }.to raise_error
    end

    it "should retry 3 times before raising an error" do
      stub_request(:get, 'http://text.hubspot.com/retry').to_timeout

      expect { @http_utils.fetch_url_with_retries('http://text.hubspot.com/retry') }.to raise_error

      WebMock.should have_requested(:get, "http://text.hubspot.com/retry").times(3)

    end

  end
end
