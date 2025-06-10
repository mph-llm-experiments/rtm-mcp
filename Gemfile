# Gemfile for RTM MCP Server
source 'https://rubygems.org'

# Core MCP server functionality (already in standard library)
# - json
# - net/http
# - uri
# - digest
# - time
# - optparse

# HTTP server functionality
gem 'sinatra', '~> 3.0'
gem 'rack-cors', '~> 1.1'  # Use older version compatible with Sinatra

# Development and testing
group :development, :test do
  gem 'puma', '~> 6.0'  # Better web server for Sinatra
end
