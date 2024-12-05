require_relative '../spec_helper'

RSpec.describe Flow::PRDescriptionUpdater do
  describe '.call' do
    it 'updates the PR description with the correct link' do
      allow(SystemHelper).to receive(:call).with("gh pr view pr_number --json body -q .body").and_return("Current PR body")
      allow(SystemHelper).to receive(:call).with("gh pr edit pr_number --body '[gem_name Changes](compare_url)\n\nCurrent PR body'").and_return(true)

      described_class.call('gem_name', 'compare_url', 'pr_number')

      expect(SystemHelper).to have_received(:call).with("gh pr edit pr_number --body '[gem_name Changes](compare_url)\n\nCurrent PR body'")
    end
  end
end
