require 'open3'
require 'pty'

module SystemHelper
  def self.call(command)
    output = ''
    error_output = ''
    status = nil
    Open3.popen2e(command) do |stdin, stdout_err, wait_thr|
      while line = stdout_err.gets
        output << line
      end

      status = wait_thr.value
      if status != 0
        error_output = output
        raise "Command failed: #{command}\nError output: #{error_output}"
      end
    end

    output
  end
end
