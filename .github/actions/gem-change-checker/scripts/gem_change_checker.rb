#!/usr/bin/env ruby

require 'json'

class GemChangeChecker
  USAGE_MESSAGE = "Usage: #{$0} <gem_name>"
  BASE_BRANCH = 'main'

  def initialize(gem_name:)
    @github_event = JSON.parse(ENV['GITHUB_EVENT'])

    @gem_name = gem_name

    validate_arguments
  end

  def call
    if current_body.include?("[#{@gem_name} PR](")
      puts "PR already contains a link to the #{@gem_name} changes."
      return
    end

    if old_revision.empty? || new_revision.empty? || old_revision == new_revision
      puts "No relevant changes detected."
      return
    end

    updated_body = if current_body.include?(link_marker)
                     current_body.gsub(/^#{Regexp.escape(link_marker)}\(.*\)$/, new_link)
                   else
                     "#{new_link}\n\n#{current_body}"
                   end

    `gh pr edit #{pr_number} --body "#{updated_body}"`
  end

  private

  def validate_arguments
    abort(USAGE_MESSAGE) if @gem_name.nil? || @gem_name.strip.empty?
  end

  def gem_repo_url
    "https://github.com/sofatutor/#{@gem_name}"
  end

  def old_revision
    @old_revision ||= `git show origin/#{BASE_BRANCH}:Gemfile.lock | grep -A 1 "#{@gem_name}" | grep revision | awk '{print $2}'`
    @old_revision.strip
  end

  def new_revision
    @new_revision ||= `grep -A 1 "#{@gem_name}" Gemfile.lock | grep revision | awk '{print $2}'`
    @new_revision.strip
  end

  def compare_url
    "#{gem_repo_url}/compare/#{old_revision}...#{new_revision}"
  end

  def pr_number
    @github_event['pull_request']['number']
  end

  def current_body
    @current_body ||= `gh pr view #{pr_number} --json body -q '.body'`
    @current_body.strip
  end

  def link_marker
    "[#{@gem_name} Changes]"
  end

  def new_link
    "#{link_marker}(#{compare_url})"
  end
end

GemChangeChecker.new(gem_name: ARGV[0]).call
