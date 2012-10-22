#!/usr/bin/env rake
require 'bundler/setup'
require 'rake'
require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
desc 'Default: run the specs and features.'
task :default do
  system("bundle exec rake -s spec ;")
end

RSpec::Core::RakeTask.new
