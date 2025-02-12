#!/usr/bin/env ruby

require 'json'

class GemDependencyUpdater
  USAGE_MESSAGE = "Usage: #{$0} <gem_name>"
  GIT_USER_NAME = 'sofatutor-bot'
  GIT_USER_EMAIL = 'operations+github-bot@sofatutor.com'
  GEMFILE_PATH = 'Gemfile'
  BASE_BRANCH = 'main'

  def initialize(gem_name:)
    @github_event = JSON.parse(ENV['GITHUB_EVENT'])

    @gem_name = gem_name

    validate_arguments
  end

  def call
    checkout_branch
    update_gem_dependency
    commit_and_push_changes
    create_pull_request
  end

  private

  def branch_name
    if merged?
      @github_event['pull_request']['base']['ref']
    else
      @github_event['pull_request']['head']['ref']
    end
  end

  def dependent_repo_branch_name
    @github_event['pull_request']['head']['ref']
  end

  def merged?
    @github_event['pull_request']['merged'] == true
  end

  def validate_arguments
    abort(USAGE_MESSAGE) if @gem_name.nil? || @gem_name.strip.empty?
  end

  def checkout_branch
    execute_command("git fetch --depth=1 origin", "Failed to fetch from origin.")
    checkout_cmd = <<~CMD
      git checkout #{dependent_repo_branch_name} 2>/dev/null \
        || git checkout -b #{dependent_repo_branch_name} origin/#{dependent_repo_branch_name} 2>/dev/null \
        || git checkout -b #{dependent_repo_branch_name}
    CMD
    execute_command(checkout_cmd, "Failed to checkout or create branch '#{dependent_repo_branch_name}'.")
    execute_command("git pull", "Failed to pull latest changes for branch '#{dependent_repo_branch_name}'.", graceful: true)
  end

  def update_gem_dependency
    execute_command("bundle config set --local frozen false", "Failed to set bundle config.")
    gemfile = File.read(GEMFILE_PATH)
    new_gemfile = gemfile.gsub(/(gem '#{Regexp.escape(@gem_name)}',.*branch: )'[^']*'/) do
      "#{$1}'#{branch_name}'"
    end
    File.write(GEMFILE_PATH, new_gemfile)
    execute_command("bundle update #{@gem_name} --conservative", "Failed to update gem dependency.")
  end

  def commit_and_push_changes
    configure_git_user
    execute_command('git add Gemfile Gemfile.lock')
    commit_message = "Update #{@gem_name} to feature branch #{branch_name}"
    output = execute_command("git commit -m \"#{commit_message}\"", "Failed to commit changes.", graceful: true)

    if output.include?('nothing to commit, working tree clean')
      puts "Nothing to commit, working tree clean."
      return
    end

    execute_command("git push origin #{dependent_repo_branch_name}")
  end

  def create_pull_request
    pr_title = @github_event['pull_request']['base']['ref']
    sc_number = pr_title[/\[SC-\d+\]/]
    pr_title.gsub!(/\[SC-\d+\]/, '')

    create_pr_command = [
      "gh pr create",
      "--title \"#{sc_number} Update #{@gem_name}: #{pr_title.strip}\"",
      "--body \"This PR updates the #{@gem_name} to the latest feature branch.\"",
      "--head #{dependent_repo_branch_name}",
      "--base #{BASE_BRANCH}"
    ].join(' ')

    puts "Creating pull request for branch '#{branch_name}'..."

    output = execute_command(create_pr_command, 'Failed to create pull request.', graceful: true)

    if output.include?('already exists')
      puts "Pull request already exists for branch '#{branch_name}'."
      return
    end
  end

  def configure_git_user
    execute_command("git config user.name \"#{GIT_USER_NAME}\"")
    execute_command("git config user.email \"#{GIT_USER_EMAIL}\"")
  end

  def execute_command(command, error_message = nil, graceful: false)
    puts "Executing: #{command}"
    output = `#{command} 2>&1`

    unless $?.success?
      error_message ||= "Command failed: #{command}"

      if graceful
        puts "#{error_message}\nOutput: #{output}"
      else
        abort("#{error_message}\nOutput: #{output}")
      end
    end

    output
  end
end

GemDependencyUpdater.new(gem_name: ARGV[0]).call
