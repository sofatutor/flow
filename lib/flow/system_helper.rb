require 'open3'
require 'pty'

module SystemHelper
  def self.call(command, use_pty: false)
    if use_pty
      output = ''
      PTY.spawn(command) do |stdout, _stdin, _pid|
        stdout.each { |line| output << line }
      end
      output
    else
      output, error, status = Open3.capture3(command)
      raise "Error executing command: #{error}" unless status.success?

      output
    end
  end
end
