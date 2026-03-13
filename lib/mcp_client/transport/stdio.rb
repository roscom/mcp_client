require 'open3'
require 'json'

module McpClient
  module Transport
    class Stdio
      def initialize(command, args: [])
        @command = command
        @args = args
        @stdin = nil
        @stdout = nil
        @stderr = nil
        @wait_thread = nil
      end

      def start
        @stdin, @stdout, @stderr, @wait_thread = Open3.popen3(@command, *@args)
      rescue Errno::ENOENT => e
        raise ConnectionError, "Cannot start '#{@command}': #{e.message}"
      end

      def send_request(payload)
        write_line(payload.to_json)

        loop do
          line = @stdout.gets
          raise ConnectionError, 'MCP server process terminated' if line.nil?

          line = line.strip
          next if line.empty?

          begin
            parsed = JSON.parse(line)
            return parsed if parsed.key?('id')
          rescue JSON::ParserError
            next
          end
        end
      rescue IOError, Errno::EPIPE => e
        raise ConnectionError, "Lost connection to MCP server: #{e.message}"
      end

      def send_notification(payload)
        write_line(payload.to_json)
      rescue IOError, Errno::EPIPE
        nil # fire-and-forget
      end

      def close
        @stdin&.close rescue nil
        @stdout&.close rescue nil
        @stderr&.close rescue nil
        @wait_thread&.kill rescue nil
      end

      private

      def write_line(data)
        @stdin.puts(data)
        @stdin.flush
      end
    end
  end
end
