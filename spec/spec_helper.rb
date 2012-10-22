require 'bundler'
Bundler.setup(:default, :development)
require 'simplecov' unless ENV['TRAVIS']
Bundler.require

require 'rubycas-client'

SPEC_TMP_DIR="spec/tmp"

Dir["./spec/support/**/*.rb"].each do |f|
  require f.gsub('.rb','') unless f.end_with? '_spec.rb'
end

RSpec.configure do |config|
  config.mock_with :rspec
  config.mock_framework = :rspec
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.filter_run_including :focus
  config.run_all_when_everything_filtered = true
  config.fail_fast = false
  # create tmp directory
  config.before(:all) do
    FileUtils.mkdir_p(SPEC_TMP_DIR)
  end
  # get rid of all test fiels
  config.after(:all) do
    FileUtils.rm_rf(SPEC_TMP_DIR)
  end
end

