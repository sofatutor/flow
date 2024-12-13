require 'open3'

module SystemHelper
  def self.call(*command_or_pipe)
    command = command_or_pipe.join(' | ')
    output = `#{command}`
    raise "Command failed: #{command}" unless $?.success?

    output
  end
end
