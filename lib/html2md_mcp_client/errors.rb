module Html2mdMcpClient
  class Error < StandardError; end
  class ConnectionError < Error; end
  class ProtocolError < Error; end
  class ToolError < Error; end
  class NotConnectedError < Error; end
end
