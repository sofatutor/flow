# flow

flow is a repository of GitHub Actions. sofatutor-bot is the GitHub account those actions commit as.

GitHub actions that keep the sofatutor apps aligned with bass, cobain, and SPASS.

A ready-for-review pull request in one of those gems opens a draft pull request in sofatutor and sofatutor-kids. It points the gem's `branch:` in the Gemfile at the gem branch and updates `Gemfile.lock`. Merging the gem pull request points the gem back at `main`.

Drafts are skipped, and so are pull requests labeled `avoid gem dependency updater` or `dependencies`.

A pull request in either app that changes `Gemfile.lock` gets a compare link in the description when a gem revision moved.
