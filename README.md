# Check Action Versions

> [!IMPORTANT]
> **This project is retired and the repository is archived.** It will receive no further releases, fixes, or security updates. Use [Dependabot version updates](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/configure-version-updates) with the `github-actions` ecosystem instead. It is built into GitHub and covers what this action did.

## Why it was retired

This action scanned `uses:` references in workflow files, resolved each action's latest release, and opened a PR that rewrote the commit SHA and the release comment. Dependabot does the same work natively:

- It updates actions referenced by commit SHA, such as `actions/checkout@<commit>`.
- It updates the version comment when the comment sits on the same line, such as `actions/checkout@<commit> # v6.0.2`.
- With `directory: "/"` it scans `.github/workflows/` and the root `action.yml` / `action.yaml`.
- It needs no PAT, bot account, or signing key in your repo, and no workflow to maintain.

Sources: GitHub Docs, [Dependabot options reference](https://docs.github.com/en/code-security/reference/supply-chain-security/dependabot-options-reference) and [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use#keeping-the-actions-in-your-workflows-secure-and-up-to-date).

## Migrating to Dependabot

1. Add `.github/dependabot.yml`:

   ```yaml
   version: 2
   updates:
     - package-ecosystem: github-actions
       directory: /
       schedule:
         interval: weekly
         day: monday
         time: "09:00"
         timezone: UTC
       commit-message:
         prefix: "chore(deps)"
       labels:
         - dependencies
         - security
       groups:
         github-actions:
           patterns:
             - "*"
   ```

   The `groups` block puts every action update in one PR, like this action did. Remove it to get one PR per action, which is Dependabot's default.

2. Delete the workflow that called `nerdalytics/check-action-versions` (for example `.github/workflows/check-action-versions.yml`).

3. Optional cleanup. Remove the secrets you created only for this action, such as the bot PAT and the SSH or GPG signing key. Close the old `Security: Outdated GitHub Actions detected` tracking issue and delete the `update-github-actions` branch if they still exist.

4. Optional. Turn on [Dependabot security updates](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/secure-your-dependencies/configure-security-updates) to get PRs for actions that have published security advisories.

### Input mapping

| `check-action-versions` input | Dependabot equivalent |
|-------------------------------|-----------------------|
| Caller workflow `on.schedule` | `schedule.interval` (plus `day`, `time`, `timezone`) |
| `scan-globs` | `directory: /` (`.github/workflows/` and root `action.yml`). |
| `commit-prefix` | `commit-message.prefix` |
| `pr-labels` | `labels` |
| `branch-name` | Set by Dependabot. With `groups`, the group identifier is used in the branch name and PR title. |
| `outdated-behavior` (`issue-only`, `dry-run`) | No equivalent. Dependabot opens PRs. |
| `issue-labels`, `issue-title`, tracking issue | No equivalent. Dependabot does not open a tracking issue. |
| `committer-name`, `committer-email`, `gh-pat`, `signing-*` | Not needed. Dependabot authors its own commits and PRs. |

## Existing pins keep working

Archiving makes the repository read-only. Its commits, tags, and releases are kept, so existing SHA pins still point at the same code. That code will not get fixes, so migrate when you can.

The full documentation for the last release is in the [v1.0.3 README](https://github.com/nerdalytics/check-action-versions/blob/v1.0.3/README.md).

## License

MIT. See [LICENSE](./LICENSE).
