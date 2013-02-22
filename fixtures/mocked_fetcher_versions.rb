require 'json'
require 'asset_bender_test'

MOCKED_URLS = {
  "http://somecrazydomain.net/project2" => "",
  "http://somecrazydomain.net/project1/latest-version-2.1" => "v2.1.3",
  "http://somecrazydomain.net/project1/latest-version-2.1-qa" => "v2.1.7",

  "http://somecrazydomain.net/project1/v2.1.7/premunged-static-contents-hash.md5" => "<some hash>",
  "http://somecrazydomain.net/project1/v2.1.7/info.txt" => "<some info>",
  "http://somecrazydomain.net/project1/v2.1.7/component.json" => File.read(fixture_path("project1/component.json")),
  "http://somecrazydomain.net/project1/v2.1.7/denormalized-deps.json" => {
    "project2" => "0.1.5",
    "another_dep" => "1.12.23",
  }.to_json,
}

