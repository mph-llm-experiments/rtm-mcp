#!/usr/bin/env ruby

require 'minitest/autorun'
require 'minitest/spec'  # For describe/it syntax
require 'webmock/minitest'  # Mock HTTP requests
require 'mocha/minitest'    # For mocking and stubbing
require_relative 'rtm-mcp'

# Minitest with traditional TestCase style
class RateLimiterTest < Minitest::Test
  def setup
    @rate_limiter = RateLimiter.new(requests_per_second: 2, burst: 3)
  end

  def test_initialization
    assert_equal 2, @rate_limiter.instance_variable_get(:@requests_per_second)
    assert_equal 3, @rate_limiter.instance_variable_get(:@burst)
    assert_equal 0.5, @rate_limiter.instance_variable_get(:@min_interval)
  end

  def test_wait_if_needed_no_wait_when_under_burst
    # Should not wait for first few requests
    start_time = Time.now
    @rate_limiter.wait_if_needed
    @rate_limiter.wait_if_needed
    @rate_limiter.wait_if_needed
    end_time = Time.now
    
    # Should complete quickly (under 0.1 seconds)
    assert (end_time - start_time) < 0.1
  end
end

# Minitest with describe/it syntax (more like RSpec)
describe RTMClient do
  before do
    @api_key = 'test_api_key'
    @shared_secret = 'test_secret'
    @client = RTMClient.new(@api_key, @shared_secret)
  end

  describe '#initialize' do
    it 'sets api key and shared secret' do
      assert_equal 'test_api_key', @client.instance_variable_get(:@api_key)
      assert_equal 'test_secret', @client.instance_variable_get(:@shared_secret)
    end

    it 'creates a rate limiter' do
      rate_limiter = @client.instance_variable_get(:@rate_limiter)
      assert_instance_of RateLimiter, rate_limiter
    end
  end

  describe '#call_method' do
    it 'makes HTTP request with correct parameters' do
      # Mock the HTTP response
      stub_request(:get, "https://api.rememberthemilk.com/services/rest/")
        .with(query: hash_including(method: 'rtm.test.echo', api_key: @api_key))
        .to_return(status: 200, body: '{"rsp": {"stat": "ok"}}')

      result = @client.call_method('rtm.test.echo', { test: 'hello' })
      
      assert_equal 'ok', result.dig('rsp', 'stat')
    end

    it 'handles HTTP errors gracefully' do
      stub_request(:get, "https://api.rememberthemilk.com/services/rest/")
        .to_return(status: 500, body: 'Server Error')

      result = @client.call_method('rtm.test.echo')
      
      assert result['error']
      assert_includes result['error'], 'HTTP 500'
    end
  end

  describe '#generate_signature' do
    it 'generates correct MD5 signature' do
      params = { method: 'rtm.test.echo', api_key: 'test' }
      signature = @client.send(:generate_signature, params)
      
      # Should return a 32-character hex string
      assert_match /\A[a-f0-9]{32}\z/, signature
    end
  end
end

describe RTMMCPServer do
  before do
    @server = RTMMCPServer.new('test_api_key', 'test_secret')
  end

  describe '#initialize' do
    it 'requires api_key and shared_secret' do
      assert_raises RuntimeError do
        RTMMCPServer.new(nil, nil)
      end
    end

    it 'sets up tools array' do
      tools = @server.instance_variable_get(:@tools)
      assert_instance_of Array, tools
      refute_empty tools
      
      # Check that test_connection tool exists
      test_tool = tools.find { |t| t[:name] == 'test_connection' }
      assert test_tool
      assert_equal 'Test basic connectivity to RTM API', test_tool[:description]
    end
  end

  describe '#handle_request' do
    it 'handles initialize method' do
      request = { 'method' => 'initialize' }
      response = @server.handle_request(request)
      
      assert_equal '2024-11-05', response[:protocolVersion]
      assert response[:capabilities]
      assert response[:serverInfo]
    end

    it 'handles tools/list method' do
      request = { 'method' => 'tools/list' }
      response = @server.handle_request(request)
      
      assert response[:tools]
      assert_instance_of Array, response[:tools]
    end

    it 'returns error for unknown method' do
      request = { 'method' => 'unknown_method' }
      response = @server.handle_request(request)
      
      assert response[:error]
      assert_equal -32601, response[:error][:code]
    end
  end
end
