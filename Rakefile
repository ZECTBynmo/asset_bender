task :default => :spec

require 'rspec/core/rake_task'; 
RSpec::Core::RakeTask.new(:spec)

require "rake/testtask"
Rake::TestTask.new do |t|
  t.libs << "lib"
  t.libs << "test"
  t.warning = true
  t.test_files = FileList['test/*_test.rb']
end

