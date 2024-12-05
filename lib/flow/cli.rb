require 'thor'
require 'tty-prompt'
require_relative 'update_pr_description'

module Flow
  class CLI < Thor
    desc "update_pr GEM_NAME COMPARE_URL PR_NUMBER", "Update the PR description with a link to gem changes"
    def update_pr(gem_name, compare_url, pr_number)
      prompt = TTY::Prompt.new

      github_token = ENV['GITHUB_TOKEN'] || (prompt.ask('Enter your GitHub token:') if prompt.stdin.tty?)
      github_repository = ENV['GITHUB_REPOSITORY'] || (prompt.ask('Enter your GitHub repository:') if prompt.stdin.tty?)

      ENV['GITHUB_TOKEN'] = github_token if github_token
      ENV['GITHUB_REPOSITORY'] = github_repository if github_repository

      required_env_vars = %w[GITHUB_TOKEN GITHUB_REPOSITORY]
      required_env_vars.each do |var|
        ENV.fetch(var) { raise "Environment variable #{var} is required" }
      end

      Flow::PRDescriptionUpdater.call(gem_name, compare_url, pr_number)
    end
  end
end

Flow::CLI.start(ARGV) if __FILE__ == $PROGRAM_NAME
