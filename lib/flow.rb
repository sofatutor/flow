$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

module Flow
  require 'flow/cli'
  require 'flow/gem_revision_checker'
  require 'flow/pr_description_updater'
end
