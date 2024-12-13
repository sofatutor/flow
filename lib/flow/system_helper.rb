require 'open3'
require 'pty'

module SystemHelper
  class << self
    def call(*command_or_pipe, pty: false)
      command = command_or_pipe.join(' | ')
      output, status = pty ? execute_with_pty(command) : execute_with_tty(command)
      raise "Command failed: #{command}" unless status == 0

      output
    end

    private

    def execute_with_tty(command)
      output = ''
      Open3.popen2e(command) do |stdin, stdout_err, wait_thr|
        while line = stdout_err.gets
          puts line
          output << line
        end

        status = wait_thr.value
        raise "Command failed: #{command}" unless status == 0
      end

      [output, status]
    end

    def execute_with_pty(command)
      output = ''

      PTY.spawn(command) do |stdout, stdin, pid|
        begin
          stdout.each_char { |c| print c; output << c }
        rescue Errno::EIO
          # End of output
        end
        Process.wait(pid)
      end

      [output, $?.exitstatus]
    end
  end
end
