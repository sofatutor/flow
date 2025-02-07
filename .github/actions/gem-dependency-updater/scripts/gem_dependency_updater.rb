#!/usr/bin/env ruby

require 'json'

class GemDependencyUpdater
  USAGE_MESSAGE = "Usage: #{$0} <branch_name> <gem_name>"
  GIT_USER_NAME = 'sofatutor-bot'
  GIT_USER_EMAIL = 'operations+github-bot@sofatutor.com'
  GEMFILE_PATH = 'Gemfile'
  BASE_BRANCH = 'main'

  def initialize(branch_name:, gem_name:)
    @github_event = JSON.parse(ENV['GITHUB_EVENT'])

    @branch_name = branch_name
    @gem_name = gem_name

    @dependent_repo_branch_name =
      if is_merge_event?
        @github_event['pull_request']['head']['ref']
      else
        @branch_name
      end

    if @github_event['pull_request']['labels'].any? { |label| label['name'] == 'avoid gem dependency updater' }
      puts "Skipping gem dependency update for branch '#{@branch_name}' due to 'avoid gem dependency updater' label."
      exit
    end

    validate_arguments
  end

  def call
    checkout_branch
    update_gem_dependency
    commit_and_push_changes
    create_pull_request
  end

  private

  def is_merge_event?
    return false unless @github_event['action'] == 'closed'
    return false unless @github_event['pull_request']

    @github_event['pull_request']['merged'] == true
  end

  def validate_arguments
    abort(USAGE_MESSAGE) if @branch_name.nil? || @branch_name.strip.empty? || @gem_name.nil? || @gem_name.strip.empty?
  end

  def checkout_branch
    execute_command("git fetch --depth=1 origin", "Failed to fetch from origin.")
    checkout_cmd = <<~CMD
      git checkout #{@dependent_repo_branch_name} 2>/dev/null \
        || git checkout -b #{@dependent_repo_branch_name} origin/#{@dependent_repo_branch_name} 2>/dev/null \
        || git checkout -b #{@dependent_repo_branch_name}
    CMD
    execute_command(checkout_cmd, "Failed to checkout or create branch '#{@dependent_repo_branch_name}'.")
    execute_command("git pull", "Failed to pull latest changes for branch '#{@dependent_repo_branch_name}'.", graceful: true)
  end

  def update_gem_dependency
    execute_command("bundle config set --local frozen false", "Failed to set bundle config.")
    gemfile = File.read(GEMFILE_PATH)
    new_gemfile = gemfile.gsub(/(gem '#{Regexp.escape(@gem_name)}',.*branch: )'[^']*'/) do
      "#{$1}'#{@branch_name}'"
    end
    File.write(GEMFILE_PATH, new_gemfile)
    execute_command("bundle update #{@gem_name} --conservative", "Failed to update gem dependency.")
  end

  def commit_and_push_changes
    configure_git_user
    execute_command('git add Gemfile Gemfile.lock')
    commit_message = "Update #{@gem_name} to feature branch #{@branch_name}"
    output = execute_command("git commit -m \"#{commit_message}\"", "Failed to commit changes.", graceful: true)

    if output.include?('nothing to commit, working tree clean')
      puts "Nothing to commit, working tree clean."
      return
    end

    execute_command("git push origin #{@dependent_repo_branch_name}")
  end

  def create_pull_request
    create_pr_command = [
      "gh pr create",
      "--title \"Update #{@gem_name} to branch #{@branch_name}\"",
      "--body \"This PR updates the #{@gem_name} to the latest feature branch.\"",
      "--head #{@dependent_repo_branch_name}",
      "--base #{BASE_BRANCH}"
    ].join(' ')

    puts "Creating pull request for branch '#{@branch_name}'..."

    output = execute_command(create_pr_command, "Failed to create pull request.", graceful: true)

    if output.include?('already exists')
      puts "Pull request already exists for branch '#{@branch_name}'."
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

GemDependencyUpdater.new(branch_name: ARGV[0], gem_name: ARGV[1]).call
