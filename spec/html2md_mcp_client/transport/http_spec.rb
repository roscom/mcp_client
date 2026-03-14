require 'spec_helper'

RSpec.describe Html2mdMcpClient::Transport::Http do
  let(:url) { 'http://localhost:3001/mcp' }
  let(:transport) { described_class.new(url) }

  describe '#send_request' do
    it 'sends a POST with JSON body and returns parsed response' do
      payload = { jsonrpc: '2.0', id: 1, method: 'initialize', params: {} }
      response_body = { 'jsonrpc' => '2.0', 'id' => 1, 'result' => { 'ok' => true } }

      stub_request(:post, url)
        .with(
          body: payload.to_json,
          headers: { 'Content-Type' => 'application/json', 'Accept' => 'application/json, text/event-stream' }
        )
        .to_return(status: 200, body: response_body.to_json, headers: { 'Content-Type' => 'application/json' })

      expect(transport.send_request(payload)).to eq(response_body)
    end

    it 'captures session ID from response headers' do
      stub_request(:post, url)
        .to_return(
          status: 200,
          body: { 'jsonrpc' => '2.0', 'id' => 1, 'result' => {} }.to_json,
          headers: { 'Mcp-Session-Id' => 'abc-123' }
        )

      transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} })
      expect(transport.session_id).to eq('abc-123')
    end

    it 'sends session ID on subsequent requests' do
      # First request sets session
      stub_request(:post, url)
        .to_return(
          status: 200,
          body: { 'jsonrpc' => '2.0', 'id' => 1, 'result' => {} }.to_json,
          headers: { 'Mcp-Session-Id' => 'abc-123' }
        )

      transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} })

      # Second request should include session header
      stub_request(:post, url)
        .with(headers: { 'Mcp-Session-Id' => 'abc-123' })
        .to_return(
          status: 200,
          body: { 'jsonrpc' => '2.0', 'id' => 2, 'result' => {} }.to_json
        )

      transport.send_request({ jsonrpc: '2.0', id: 2, method: 'test2', params: {} })
    end

    it 'parses SSE responses' do
      sse_body = "event: message\ndata: {\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"tools\":[]}}\n\n"

      stub_request(:post, url)
        .to_return(
          status: 200,
          body: sse_body,
          headers: { 'Content-Type' => 'text/event-stream' }
        )

      result = transport.send_request({ jsonrpc: '2.0', id: 1, method: 'tools/list', params: {} })
      expect(result).to eq({ 'jsonrpc' => '2.0', 'id' => 1, 'result' => { 'tools' => [] } })
    end

    it 'raises ConnectionError on HTTP error status' do
      stub_request(:post, url).to_return(status: 500, body: 'Internal Server Error')

      expect { transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} }) }
        .to raise_error(Html2mdMcpClient::ConnectionError, /HTTP 500/)
    end

    it 'raises ConnectionError on connection refused' do
      stub_request(:post, url).to_raise(Errno::ECONNREFUSED)

      expect { transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} }) }
        .to raise_error(Html2mdMcpClient::ConnectionError, /Cannot connect/)
    end

    it 'raises ConnectionError on open timeout' do
      stub_request(:post, url).to_raise(Net::OpenTimeout)

      expect { transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} }) }
        .to raise_error(Html2mdMcpClient::ConnectionError, /Cannot connect/)
    end

    it 'raises ConnectionError on read timeout' do
      stub_request(:post, url).to_raise(Net::ReadTimeout)

      expect { transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} }) }
        .to raise_error(Html2mdMcpClient::ConnectionError, /Cannot connect/)
    end

    it 'raises ConnectionError on network unreachable' do
      stub_request(:post, url).to_raise(Errno::ENETUNREACH)

      expect { transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} }) }
        .to raise_error(Html2mdMcpClient::ConnectionError, /Cannot connect/)
    end

    it 'raises ConnectionError on connection reset' do
      stub_request(:post, url).to_raise(Errno::ECONNRESET)

      expect { transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} }) }
        .to raise_error(Html2mdMcpClient::ConnectionError, /Cannot connect/)
    end

    it 'raises ConnectionError on connection timed out' do
      stub_request(:post, url).to_raise(Errno::ETIMEDOUT)

      expect { transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} }) }
        .to raise_error(Html2mdMcpClient::ConnectionError, /Cannot connect/)
    end

    it 'raises ProtocolError on invalid JSON' do
      stub_request(:post, url).to_return(status: 200, body: 'not json')

      expect { transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} }) }
        .to raise_error(Html2mdMcpClient::ProtocolError, /Invalid JSON/)
    end
  end

  describe '#send_notification' do
    it 'sends a POST and does not raise on failure' do
      stub_request(:post, url).to_return(status: 500)
      expect { transport.send_notification({ jsonrpc: '2.0', method: 'notify' }) }.not_to raise_error
    end
  end

  describe '#close' do
    it 'clears the session ID' do
      stub_request(:post, url)
        .to_return(
          status: 200,
          body: { 'jsonrpc' => '2.0', 'id' => 1, 'result' => {} }.to_json,
          headers: { 'Mcp-Session-Id' => 'abc-123' }
        )

      transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} })
      expect(transport.session_id).to eq('abc-123')

      transport.close
      expect(transport.session_id).to be_nil
    end
  end

  describe 'custom headers' do
    it 'includes custom headers in requests' do
      t = described_class.new(url, headers: { 'Authorization' => 'Bearer tok123' })

      stub_request(:post, url)
        .with(headers: { 'Authorization' => 'Bearer tok123' })
        .to_return(status: 200, body: { 'jsonrpc' => '2.0', 'id' => 1, 'result' => {} }.to_json)

      t.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} })
    end
  end

  describe 'HTTPS' do
    it 'enables SSL for https URLs' do
      t = described_class.new('https://secure.example.com/mcp')

      stub_request(:post, 'https://secure.example.com/mcp')
        .to_return(status: 200, body: { 'jsonrpc' => '2.0', 'id' => 1, 'result' => {} }.to_json)

      t.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} })
    end
  end
end
