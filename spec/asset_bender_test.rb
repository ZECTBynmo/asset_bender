require 'bundler/setup'

require 'asset_bender'
require 'spec_helper'

# Don't load the ~/.bender/config.yaml while testing
AssetBender::Config.skip_global_config = true


FIXTURE_ROOT = File.expand_path(File.join(File.dirname(__FILE__), "../fixtures"))

def fixture_path(sub_path)
  File.expand_path(File.join(FIXTURE_ROOT, sub_path))
end

# Namespace shortcut
AB = AssetBender
