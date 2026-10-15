# flow

flow keeps sofatutor apps in step with the private gems they depend on. You do not run it by hand. Opening a pull request in a gem repo, or changing `Gemfile.lock` in an app, starts the workflows below.

The gems are [bass](https://github.com/sofatutor/bass), [cobain](https://github.com/sofatutor/cobain), and [SPASS](https://github.com/sofatutor/SPASS). The apps are [sofatutor](https://github.com/sofatutor/sofatutor) and [sofatutor-kids](https://github.com/sofatutor/sofatutor-kids). Each app pins those gems to a git branch in its Gemfile:

```ruby
gem 'spass', sofatutor: 'SPASS', branch: 'main'
```

## When you change a gem

bass, cobain, and SPASS each run `.github/workflows/gem_dependency_updater.yml` on a pull request. That workflow calls `.github/actions/gem-dependency-updater` in this repo, once per app.

It runs only when the gem pull request is ready for review. A draft is ignored. It also skips pull requests labeled `avoid gem dependency updater` or `dependencies`. bass skips Dependabot as well.

What it does in each app:

1. Checks out a branch with the same name as the gem pull request.
2. Points that gem's `branch:` in the Gemfile at the gem pull request branch, then updates `Gemfile.lock`.
3. Commits as sofatutor-bot and opens a draft pull request back to `main`.

The draft pull request title starts with the `[SC-123]` id from the gem pull request title, when that title has one. The assignee is the gem pull request's assignee. The milestone comes from that person's team in the app's `doc/team.yml`.

When the gem pull request is merged, the workflow runs again and points the gem back at the base branch, usually `main`, on the same app branch. The app pull request can then be merged.

The optional `add_changelog` input is off. None of the gem workflows turn it on.

## When an app lockfile changes

sofatutor and sofatutor-kids run `.github/workflows/check_gem_revision.yml` when a pull request changes `Gemfile.lock`. That workflow calls `.github/actions/gem-change-checker` for bass, cobain, and SPASS.

If the locked revision of a gem differs from `main`, the action adds a compare link to the top of the pull request description, for example `[SPASS Changes](https://github.com/sofatutor/SPASS/compare/<old>...<new>)`. It updates that link if it is already there.

`.github/workflows/check_gem_changes.yml` is the same check, written as a reusable workflow. The apps call the action, not this workflow.
