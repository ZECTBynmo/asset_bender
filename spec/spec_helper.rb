#require 'bundler/setup'
require 'simplecov'
require 'webmock/rspec'

SimpleCov.start do
  add_filter '/spec/'
  add_filter '/lib/'
end if ENV["COVERAGE"]