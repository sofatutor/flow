require 'open3'
require 'pty'

module SystemHelper
  def self.call(*command_or_pipe, pty: false)
    command = command_or_pipe.join(' | ')
    output = ''
    status = nil

    if pty
      begin
        PTY.spawn(command) do |stdout, stdin, pid|
          begin
            stdout.each_char { |c| print c; output << c }
          rescue Errno::EIO
            # End of output
          end
          Process.wait(pid)
          status = $?.exitstatus
        end
      rescue PTY::ChildExited
        # Child process exited
      end
    else
      Open3.popen2e(command) do |stdin, stdout_err, wait_thr|
        while line = stdout_err.gets
          puts line
          output << line
        end

        status = wait_thr.value
      end
    end

    raise "Command failed: #{command}" unless status == 0

    output
  end
end
