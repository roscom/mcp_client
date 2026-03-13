require 'net/http'
require 'json'

module Html2mdMcpClient
  module Transport
    class Http
      attr_reader :session_id

      def initialize(url, headers: {})
        @uri = URI(url)
        @headers = headers.merge(
          'Content-Type' => 'application/json',
          'Accept' => 'application/json, text/event-stream'
        )
        @session_id = nil
      end

      def send_request(payload)
        http = build_http
        post = Net::HTTP::Post.new(@uri.request_uri, request_headers)
        post.body = payload.to_json

        response = http.request(post)
        capture_session_id(response)

        unless response.is_a?(Net::HTTPSuccess)
          raise ConnectionError, "HTTP #{response.code}: #{response.body}"
        end

        body = response.body.to_s.strip

        if response['content-type']&.include?('text/event-stream')
          body = parse_sse(body)
        end

        JSON.parse(body)
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
        raise ConnectionError, "Cannot connect to #{@uri}: #{e.message}"
      rescue JSON::ParserError => e
        raise ProtocolError, "Invalid JSON response: #{e.message}"
      end

      def send_notification(payload)
        http = build_http
        post = Net::HTTP::Post.new(@uri.request_uri, request_headers)
        post.body = payload.to_json
        http.request(post)
      rescue StandardError
        nil # fire-and-forget
      end

      def close
        @session_id = nil
      end

      private

      def build_http
        http = Net::HTTP.new(@uri.host, @uri.port)
        http.use_ssl = (@uri.scheme == 'https')
        http.open_timeout = 10
        http.read_timeout = 120
        http
      end

      def request_headers
        h = @headers.dup
        h['Mcp-Session-Id'] = @session_id if @session_id
        h
      end

      def capture_session_id(response)
        @session_id = response['mcp-session-id'] if response['mcp-session-id']
      end

      def parse_sse(body)
        data_lines = body.lines.select { |l| l.start_with?('data:') }
        return '{}' if data_lines.empty?
        data_lines.last.sub(/^data:\s*/, '').strip
      end
    end
  end
end
