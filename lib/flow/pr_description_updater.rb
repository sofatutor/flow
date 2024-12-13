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
          diff_lines << "For full changes, please see the link above."
        end
        diff_lines.join("\n")
      end

      def update_description(pr_number)
        current_body = fetch_pr_body(pr_number)
        placeholder_pattern = /flow:#{@gem_name}_changes/
        block_pattern = /## \[#{@gem_name} Changes\].*?---\n/m

        truncated = truncate_diff(@diff_text)

        new_block = "## [#{@gem_name} Changes](#{@diff_link})"
        new_block += "\n\n```diff\n#{truncated}\n```\n" if truncated
        new_block += "\n---\n"

        if current_body.match?(placeholder_pattern)
          # First run: Replace placeholder with the new block (no marker in the block)
          updated_body = current_body.sub(placeholder_pattern, new_block)
        elsif current_body.match?(block_pattern)
          # Subsequent runs: Replace existing block using its heading as the anchor
          updated_body = current_body.gsub(block_pattern, new_block)
        else
          # No placeholder or block found: Append the block at the end
          updated_body = "#{current_body}\n\n#{new_block}"
        end

        update_pr_body(pr_number, updated_body)
      end
    end
  end
end