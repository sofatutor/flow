require 'open3'
require 'pty'

module SystemHelper
  def self.call(command)
    output = ''
    status = nil
    Open3.popen2e(command) do |stdin, stdout_err, wait_thr|
      while line = stdout_err.gets
        output << line
      end

      status = wait_thr.value
      raise "Command failed: #{command}" unless status == 0
    end

    output
  end
end
