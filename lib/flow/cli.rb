require 'thor'
require_relative 'update_pr_description'
require_relative 'check_gem_revision'

module Flow
  class CLI < Thor
    desc "update_pr_description GEM_NAME COMPARE_URL PR_NUMBER", "Update the PR description with a link to gem changes"
    def update_pr_description(gem_name, compare_url, pr_number)
      Flow::PRDescriptionUpdater.call(gem_name, compare_url, pr_number)
    end

    desc "check_gem_revision GEM_NAME MAIN_BRANCH", "Check the gem revision and print the compare URL"
    def check_gem_revision(gem_name, main_branch)
      compare_url = GemRevisionChecker.call(gem_name, main_branch)
      puts compare_url if compare_url
    end
  end
end

Flow::CLI.start(ARGV) if __FILE__ == $PROGRAM_NAME
