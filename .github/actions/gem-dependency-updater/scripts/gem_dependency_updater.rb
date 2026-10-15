#!/usr/bin/env ruby

require 'base64'
require 'benchmark'
require 'json'
require 'net/http'
require 'open3'
require 'uri'
require 'yaml'

class GemDependencyUpdater
  USAGE_MESSAGE = "Usage: #{$0} <gem_name>"
  GEMFILE_PATH = 'Gemfile'
  GRAPHQL_ENDPOINT = URI('https://api.github.com/graphql')
  CREATE_COMMIT_QUERY = <<~GRAPHQL
    mutation($input: CreateCommitOnBranchInput!) {
      createCommitOnBranch(input: $input) {
        commit { oid }
      }
    }
  GRAPHQL
  BASE_BRANCH = 'main'
  TEAMS_TO_MILESTONES = {
    'Blue' => "Team Blue 🔷",
    'Green' => "Team Green ☘️",
    'Orange' => "Team Orange 🔶",
    'Purple' => "Team Purple 🌸",
    'Yellow' => "Team Yellow ☀️",
    'Black' => nil
  }

  def initialize(gem_name:, add_changelog: 'false')
    @github_event = JSON.parse(ENV['GITHUB_EVENT'])

    @gem_name = gem_name
    @add_changelog = !add_changelog.nil? && add_changelog != 'false'

    puts "Adding changelog: #{@add_changelog}"

    validate_arguments
  end

  def call
    checkout_branch
    update_gem_dependency
    commit_and_push_changes
    create_pull_request
    add_changelog
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
    execute_command("git fetch --depth=1 origin #{dependent_repo_branch_name}", "Failed to fetch from origin.", graceful: true)
    checkout_cmd = <<~CMD
      git checkout #{dependent_repo_branch_name} 2>/dev/null \
        || git checkout -b #{dependent_repo_branch_name} origin/#{dependent_repo_branch_name} 2>/dev/null \
        || git checkout -b #{dependent_repo_branch_name}
    CMD
    execute_command(checkout_cmd, "Failed to checkout or create branch '#{dependent_repo_branch_name}'.")
    execute_command("git pull origin #{dependent_repo_branch_name}", "Failed to pull latest changes for branch '#{dependent_repo_branch_name}'.", graceful: true)
  end

  def update_gem_dependency
    execute_command("bundle config set --local frozen false", "Failed to set bundle config.")
    gemfile = File.read(GEMFILE_PATH)
    new_gemfile = gemfile.gsub(/(gem '#{Regexp.escape(@gem_name)}',.*branch: )'[^']*'/) do
      "#{$1}'#{branch_name}'"
    end
    File.write(GEMFILE_PATH, new_gemfile)
    execute_command("bundle lock --update=#{@gem_name} --conservative", "Failed to update gem dependency.")
  end

  def add_changelog
    return unless @add_changelog
    return unless File.exist?('bin/changelog')
    return unless execute_command("git diff main -- \!undeployed-changes").empty?

    execute_command("bin/changelog change Update #{@gem_name}: #{pr_title}", "Failed to add changelog.", graceful: true)
    execute_command("git push origin #{dependent_repo_branch_name}")
  end

  def commit_and_push_changes
    changes = gemfile_changes
    abort('Failed to read Gemfile changes.') if changes.nil?

    if changes[:additions].empty? && changes[:deletions].empty?
      puts 'Nothing to commit, working tree clean.'
      return
    end

    message = "Update #{@gem_name} to feature branch #{branch_name}"
    abort('Failed to commit changes.') unless publish_signed_commit(message, changes)
  end

  def create_pull_request
    create_pr_command = [
      "gh pr create",
      "--title \"#{sc_number} Update #{@gem_name}: #{pr_title}\"",
      "--body \"#{pr_body}\"",
      "--head #{dependent_repo_branch_name}",
      "--base #{BASE_BRANCH}",
      milestone_option,
      assignee_option,
      '--draft'
    ].join(' ')

    puts "Creating pull request for branch '#{branch_name}'..."

    output = execute_command(create_pr_command, 'Failed to create pull request.', graceful: true)

    if output.include?('already exists')
      puts "Pull request already exists for branch '#{branch_name}'."
      return
    end
  end

  def pr_title
    @github_event['pull_request']['title'].gsub(/\[SC-\d+\]/, '').strip.gsub('"', '\"')
  end

  def sc_number
    @github_event['pull_request']['title'][/\[SC-\d+\]/]
  end

  def pr_body
    <<~PR_BODY
    [#{@github_event['repository']['name']} PR](#{@github_event['pull_request']['html_url']})

    This PR updates #{@github_event['repository']['name']} to the latest feature branch.
    PR_BODY
  end

  def milestone_option
    return nil unless team_of_author

    milestone = TEAMS_TO_MILESTONES[team_of_author]

     "--milestone '#{milestone}'" if milestone
  end

  def assignee_option
    return nil unless author

    "--assignee '#{author}'"
  end

  def author
    return nil unless @github_event['pull_request']
    return nil unless @github_event['pull_request']['assignee']

    @github_event['pull_request']['assignee']['login']
  end

  def team_of_author
    return nil unless author
    return nil unless File.exist?('doc/team.yml')

    team_data = YAML.load_file('doc/team.yml')
    _username, details = team_data.find { |_, details| details['github'] == author }

    return nil unless details

    details['team']
  end

  def gemfile_changes
    output = git_output('status', '--porcelain=v1', '-z', '-uall', '--', GEMFILE_PATH, 'Gemfile.lock')
    return nil if output.nil?

    additions = []
    deletions = []
    output.split("\0").each do |record|
      next if record.empty?

      path = record[3..]
      next if path.nil? || path.empty?

      if record[0, 2].include?('D')
        deletions << { path: path }
      elsif File.file?(path)
        additions << { path: path, contents: Base64.strict_encode64(File.binread(path)) }
      end
    end

    { additions: additions, deletions: deletions }
  end

  def publish_signed_commit(message, changes)
    token = ENV['GITHUB_TOKEN'].to_s.strip
    abort('GITHUB_TOKEN is missing.') if token.empty?
    abort('Could not determine the repository.') if repository_name_with_owner.nil?

    ensure_remote_branch(token)
    body = post_commit(token, commit_input(message, changes))
    return true if body.dig('data', 'createCommitOnBranch', 'commit', 'oid')

    puts(body.dig('errors', 0, 'message') || 'GitHub did not create a signed commit.')
    false
  end

  def ensure_remote_branch(token)
    return if remote_branch?

    sha = git_output('rev-parse', 'HEAD')&.strip
    abort('Failed to read HEAD.') if sha.nil? || sha.empty?

    response = post_github(token, "/repos/#{repository_name_with_owner}/git/refs", {
      ref: "refs/heads/#{dependent_repo_branch_name}",
      sha: sha
    })
    return if response.is_a?(Net::HTTPSuccess)

    puts(github_error(response) || 'Failed to create the remote branch.')
    abort('Failed to commit changes.')
  end

  def remote_branch?
    output = git_output('ls-remote', '--heads', 'origin', dependent_repo_branch_name)
    !output.nil? && !output.strip.empty?
  end

  def commit_input(message, changes)
    {
      branch: {
        repositoryNameWithOwner: repository_name_with_owner,
        branchName: dependent_repo_branch_name
      },
      message: { headline: message },
      fileChanges: changes,
      expectedHeadOid: git_output('rev-parse', 'HEAD')&.strip
    }
  end

  def post_github(token, path, payload)
    uri = URI("https://api.github.com#{path}")
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = "Bearer #{token}"
      request['Accept'] = 'application/vnd.github+json'
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json
      http.request(request)
    end
  end

  def github_error(response)
    JSON.parse(response.body)['message']
  rescue JSON::ParserError
    nil
  end

  def post_commit(token, input)
    response = Net::HTTP.start(GRAPHQL_ENDPOINT.hostname, GRAPHQL_ENDPOINT.port, use_ssl: true) do |http|
      http.request(graphql_request(token, input))
    end
    JSON.parse(response.body)
  rescue JSON::ParserError
    {}
  end

  def graphql_request(token, input)
    request = Net::HTTP::Post.new(GRAPHQL_ENDPOINT)
    request['Authorization'] = "Bearer #{token}"
    request['Content-Type'] = 'application/json'
    request['Accept'] = 'application/vnd.github+json'
    request.body = { query: CREATE_COMMIT_QUERY, variables: { input: input } }.to_json
    request
  end

  def repository_name_with_owner
    url = git_output('remote', 'get-url', 'origin')&.strip
    return nil if url.nil?

    url.sub(/\.git\z/, '')[%r{github\.com[:/]([^/]+/[^/]+)\z}, 1]
  end

  def git_output(*args)
    stdout, stderr, status = Open3.capture3('git', *args)
    return stdout if status.success?

    puts stderr
    nil
  end

  def execute_command(command, error_message = nil, graceful: false)
    puts "Executing: #{command}"
    output = nil
    time = Benchmark.measure do
      output = `#{command} 2>&1`
    end

    unless $?.success?
      error_message ||= "Command failed: #{command}"

      if graceful
        puts "#{error_message}\nOutput: #{output}"
      else
        abort("#{error_message}\nOutput: #{output}")
      end
    end

    puts "Execution time: #{time.real} seconds"
    output
  end
end

GemDependencyUpdater.new(gem_name: ARGV[0], add_changelog: ARGV[1]).call
