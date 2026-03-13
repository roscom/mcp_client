require 'spec_helper'

RSpec.describe Html2mdMcpClient::Transport::Stdio do
  let(:transport) { described_class.new('echo', args: ['test']) }

  describe '#start' do
    it 'spawns the subprocess' do
      stdin = instance_double(IO)
      stdout = instance_double(IO)
      stderr = instance_double(IO)
      thread = instance_double(Thread)

      expect(Open3).to receive(:popen3).with('echo', 'test').and_return([stdin, stdout, stderr, thread])
      transport.start
    end

    it 'raises ConnectionError when command not found' do
      bad = described_class.new('nonexistent_command_xyz')
      expect { bad.start }.to raise_error(Html2mdMcpClient::ConnectionError, /Cannot start/)
    end
  end

  describe '#send_request' do
    it 'writes JSON and reads the response' do
      stdin = StringIO.new
      stdout = StringIO.new("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"ok\":true}}\n")
      stderr = StringIO.new
      thread = instance_double(Thread)

      allow(Open3).to receive(:popen3).and_return([stdin, stdout, stderr, thread])
      transport.start

      result = transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} })
      expect(result).to eq({ 'jsonrpc' => '2.0', 'id' => 1, 'result' => { 'ok' => true } })
    end

    it 'skips notifications (lines without id)' do
      lines = [
        "{\"jsonrpc\":\"2.0\",\"method\":\"notification\"}\n",
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"found\":true}}\n"
      ].join
      stdin = StringIO.new
      stdout = StringIO.new(lines)
      stderr = StringIO.new
      thread = instance_double(Thread)

      allow(Open3).to receive(:popen3).and_return([stdin, stdout, stderr, thread])
      transport.start

      result = transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} })
      expect(result['result']).to eq({ 'found' => true })
    end

    it 'skips empty lines and invalid JSON' do
      lines = [
        "\n",
        "not json\n",
        "{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{}}\n"
      ].join
      stdin = StringIO.new
      stdout = StringIO.new(lines)
      stderr = StringIO.new
      thread = instance_double(Thread)

      allow(Open3).to receive(:popen3).and_return([stdin, stdout, stderr, thread])
      transport.start

      result = transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} })
      expect(result).to eq({ 'jsonrpc' => '2.0', 'id' => 1, 'result' => {} })
    end

    it 'raises ConnectionError when process terminates (nil from gets)' do
      stdin = StringIO.new
      stdout = StringIO.new # empty — gets returns nil
      stderr = StringIO.new
      thread = instance_double(Thread)

      allow(Open3).to receive(:popen3).and_return([stdin, stdout, stderr, thread])
      transport.start

      expect { transport.send_request({ jsonrpc: '2.0', id: 1, method: 'test', params: {} }) }
        .to raise_error(Html2mdMcpClient::ConnectionError, /terminated/)
    end
  end

  describe '#send_notification' do
    it 'writes without raising on pipe error' do
      stdin = instance_double(IO)
      allow(stdin).to receive(:puts).and_raise(Errno::EPIPE)
      allow(stdin).to receive(:flush)

      stdout = StringIO.new
      stderr = StringIO.new
      thread = instance_double(Thread)

      allow(Open3).to receive(:popen3).and_return([stdin, stdout, stderr, thread])
      transport.start

      expect { transport.send_notification({ jsonrpc: '2.0', method: 'notify' }) }.not_to raise_error
    end
  end

  describe '#close' do
    it 'closes all IO streams and kills the thread' do
      stdin = instance_double(IO, close: nil)
      stdout = instance_double(IO, close: nil)
      stderr = instance_double(IO, close: nil)
      thread = instance_double(Thread, kill: nil)

      allow(Open3).to receive(:popen3).and_return([stdin, stdout, stderr, thread])
      transport.start

      expect(stdin).to receive(:close)
      expect(stdout).to receive(:close)
      expect(stderr).to receive(:close)
      expect(thread).to receive(:kill)

      transport.close
    end
  end
end
