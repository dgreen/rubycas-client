source "http://rubygems.org"

gemspec

group :development_tools do
  gem 'debugger-linecache'
  gem 'debugger'
  gem "simplecov", :require => false
  gem "fuubar"
  gem "guard"
  gem "guard-rspec"
  gem "guard-bundler"

  platforms :ruby do
    gem "sqlite3"
  end

  platforms :jruby do
    gem "jruby-openssl"
  end
end

