require 'mcp_client'
require 'webmock/rspec'

WebMock.disable_net_connect!

# Shared helpers for building JSON-RPC responses
module JsonRpcHelpers
  def jsonrpc_response(id, result)
    { 'jsonrpc' => '2.0', 'id' => id, 'result' => result }
  end

  def jsonrpc_error(id, code, message)
    { 'jsonrpc' => '2.0', 'id' => id, 'error' => { 'code' => code, 'message' => message } }
  end

  def initialize_result
    {
      'serverInfo' => { 'name' => 'test-server', 'version' => '1.0.0' },
      'capabilities' => { 'tools' => {} }
    }
  end

  # Stubs the initialize handshake for HTTP transport tests
  def stub_mcp_init(url)
    stub_request(:post, url)
      .with { |req| JSON.parse(req.body)['method'] == 'initialize' }
      .to_return(
        status: 200,
        headers: { 'Content-Type' => 'application/json', 'Mcp-Session-Id' => 'test-session-123' },
        body: jsonrpc_response(1, initialize_result).to_json
      )

    stub_request(:post, url)
      .with { |req| JSON.parse(req.body)['method'] == 'notifications/initialized' }
      .to_return(status: 200, body: '')
  end
end

RSpec.configure do |config|
  config.include JsonRpcHelpers
end
