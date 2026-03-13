require 'html2md_mcp_client/version'
require 'html2md_mcp_client/errors'
require 'html2md_mcp_client/transport/http'
require 'html2md_mcp_client/transport/stdio'
require 'html2md_mcp_client/client'

module Html2mdMcpClient
  # Connect to an MCP server over HTTP.
  #
  #   client = Html2mdMcpClient.http("http://localhost:3001/mcp")
  #   client.connect!
  #   client.list_tools
  #   client.call_tool("my_tool", { arg: "value" })
  #   client.disconnect!
  #
  def self.http(url, headers: {}, **opts)
    transport = Transport::Http.new(url, headers: headers)
    Client.new(transport, **opts)
  end

  # Connect to an MCP server over stdio (spawns a subprocess).
  #
  #   client = Html2mdMcpClient.stdio("npx", args: ["-y", "@modelcontextprotocol/server-filesystem", "/tmp"])
  #   client.connect!
  #   client.list_tools
  #   client.disconnect!
  #
  def self.stdio(command, args: [], **opts)
    transport = Transport::Stdio.new(command, args: args)
    Client.new(transport, **opts)
  end
end
