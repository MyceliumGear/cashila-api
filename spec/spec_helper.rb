$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'cashila-api'
require 'webmock/rspec'
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/fixtures/vcr'
  config.hook_into :webmock
end
