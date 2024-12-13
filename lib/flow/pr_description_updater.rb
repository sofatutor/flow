require_relative 'system_helper'

module Flow
  class PRDescriptionUpdater
    class << self
      MAX_DIFF_LINES = 100

      def call(gem_name:, pr_number:, diff_link:, diff_text: nil)
        @gem_name = gem_name
        @diff_link = diff_link
        @diff_text = diff_text
        update_description(pr_number)
      end

      private

      def fetch_pr_body(pr_number)
        pr_body = SystemHelper.call('gh pr view ' + pr_number.to_s + ' --json body -q .body')
        pr_body.strip
      end

      def update_pr_body(pr_number, updated_body)
        SystemHelper.call('gh pr edit ' + pr_number.to_s + " --body '#{updated_body}'")
      end

      def truncate_diff(diff)
        return nil unless diff
        diff_lines = diff.split("\n")
        if diff_lines.size > MAX_DIFF_LINES
          diff_lines = diff_lines.first(MAX_DIFF_LINES)
          diff_lines << "For full changes, please see the [linked diff](#{@diff_link})."
        end
        diff_lines.join("\n")
      end

      def update_description(pr_number)
        current_body = fetch_pr_body(pr_number)
        marker = "flow:#{@gem_name}_changes"
        pattern = /#{marker}.*?---\n/m

        truncated = truncate_diff(@diff_text)

        new_content = "#{marker}\n\n## #{@gem_name} Changes\n\n[#{@gem_name} changes](#{@diff_link})"
        new_content += "\n\n```diff\n#{truncated}\n```\n" if truncated
        new_content += "\n---\n"

        if current_body.match?(pattern)
          updated_body = current_body.gsub(pattern, new_content)
        elsif current_body.include?(marker)
          updated_body = current_body.sub(marker, new_content)
        else
          updated_body = "#{current_body}\n\n#{new_content}"
        end

        update_pr_body(pr_number, updated_body)
      end
    end
  end
end