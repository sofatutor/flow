require 'open3'

module SystemHelper
  def self.call(*command_or_pipe)
    command = command_or_pipe.join(' | ')
    output = ''
    error = ''
    status = nil

    Open3.popen3({ 'TERM' => 'xterm-256color' }, command) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      output = stdout.read
      error = stderr.read
      status = wait_thr.value
    end

    raise "Command failed: #{error}" unless status.success?

    output
  end
end
