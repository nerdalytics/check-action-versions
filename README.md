# Check Action Versions

A composite GitHub Action. It scans the `uses:` references in your workflow files, resolves each action's latest strict-semver release, and opens a tracking issue and automated PR when anything is outdated.

- Runs on your schedule. Weekly is typical.
- Maintains a single tracking issue, updating it on each run.
- Produces a CI-triggering PR with the SHA and tag updates applied. Optional SSH or GPG signing.
- Closes the issue and PR automatically when every action is back on its latest release.

## Quickstart

Add this to any repo you want audited. The action is pinned by commit SHA. That is the same form it will write for every other entry in your workflow files, and the form required by any repo or organization enforcing SHA-pinning on `uses:` references.

```yaml
# .github/workflows/check-action-versions.yml
name: Check Action Versions
permissions:
  contents: write
  issues: write
  pull-requests: write
on:
  schedule:
    - cron: '0 9 * * 1'   # Monday 09:00 UTC
  workflow_dispatch:

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          token: ${{ secrets.YOUR_PAT_SECRET_NAME }}
      - uses: nerdalytics/check-action-versions@0d95f1ed70576169ff3c297057b7e3fcfb909a1a # v1.0.2
        with:
          committer-name: your-bot-username
          committer-email: your-bot-email@example.com
          gh-pat: ${{ secrets.YOUR_PAT_SECRET_NAME }}
```

That is the minimum configuration. Everything else is optional.

The SHA above pins `v1.0.2`. When a newer release ships, this action opens a PR in your repo rewriting the pin to the new SHA and release name. See [Updating the pin](#updating-the-pin) if you need to do it by hand.

## Updating the pin

This action maintains its own pin in your workflow files. When a new `check-action-versions` release ships, a scheduled run opens a PR bumping the SHA and the release comment. You rarely need to do this by hand.

For the cases where you do (initial install, or after disabling the scheduled audit), resolve the latest-release commit SHA as follows.

**Via the GitHub UI:**

1. Open the [Releases page](https://github.com/nerdalytics/check-action-versions/releases).
2. Click the release you want (typically the latest).
3. The commit SHA appears in the header. Click it to see the full 40-character hash.

**Via `gh` CLI:**

```sh
# Commit SHA for a specific release tag
gh api repos/nerdalytics/check-action-versions/commits/v1.0.2 --jq .sha
```

Paste the SHA into your `uses:` line with the release name as a comment:

```yaml
      - uses: nerdalytics/check-action-versions@<40-char-commit-sha> # v1.0.2
```

The comment is documentation. GitHub resolves the action at the SHA. Humans reading the file and this action's own update logic use the comment to confirm which release a given SHA corresponds to.

## Permissions

Your caller workflow needs `contents: write`, `issues: write`, and `pull-requests: write`. Declare them at workflow or job level.

```yaml
permissions:
  contents: write
  issues: write
  pull-requests: write
```

## Inputs

### Required

#### `committer-name`

Git `user.name` on the automated commit. Required. A silent `github-actions[bot]` fallback would surprise anyone scanning your repo's history, and your personal identity is the wrong owner for a bot commit. Set it explicitly.

#### `committer-email`

Git `user.email` on the automated commit. Use a `noreply.github.com` address tied to the bot account that owns the PAT. This keeps the commit author visually consistent with the PR author, and lets the "Verified" badge (when signing is enabled) resolve to the correct account.

### Optional

#### `commit-prefix`

Default: empty.

Prepended to both the commit message and the PR title.

Examples:

- `chore(core):` — Conventional Commits with a `core` scope.
- `build(deps):` — Conventional Commits, what Dependabot emits.
- `ci:` — short form.
- empty — plain prose (commit reads `Update N GitHub Action(s) to latest versions`).

Why there is no default: Conventional Commits is a convention, and many repos don't use it. A baked-in prefix would pollute commits in those repos. Supply the prefix you want, or leave it empty for plain prose.

#### `scan-globs`

Default: `.github/workflows/*.yml`.

Newline-separated list of globs telling the action which files to scan for `uses:` references.

Override if:

- Your repo has `.yaml` (not `.yml`) workflow files. Add `.github/workflows/*.yaml`.
- Your repo ships a composite action. Add `action.yml` or `**/action.yml`.

Why this default: it matches GitHub's universal workflow location, so it leaks nothing about a specific repo's setup.

#### `branch-name`

Default: `update-github-actions`.

Branch name for the automated PR. The branch is deleted and recreated on each run that has changes, so a stable name is fine.

Override if:

- You are running two parallel callers (during migration, use a `-v2` suffix for the pilot).
- Your repo has a branch-naming convention you want enforced.

#### `outdated-behavior`

Default: `both`.

What happens when the scan finds outdated actions:

- `both` — create or update a tracking issue **and** open a PR with the fixes. The recommended default: most visible, most actionable.
- `pr-only` — open a PR, no issue.
- `issue-only` — create or update the issue, no PR. Humans apply the fixes manually. Safer for repos without a bot PAT.
- `dry-run` — log findings, do nothing else. Useful for the first few weeks after adopting.

#### `up-to-date-behavior`

Default: `close`.

What happens when every action is current:

- `close` — close the tracking issue and any open automated PR. Recommended; signals cleanly that the alert is resolved.
- `keep` — leave them open. Useful if humans are mid-review.
- `silent` — no-op.

#### `pr-labels`

Default: empty.

Comma-separated labels applied to the automated PR. Example: `security,dependencies`. Labels must already exist in your repo. The action does not create them. Explicit is better than magic.

#### `issue-labels`

Default: empty.

Same as above, for the tracking issue.

#### `issue-title`

Default: `Security: Outdated GitHub Actions detected`.

The fixed title the action uses to find its own issue across runs, so it updates an existing issue instead of creating a duplicate. Framed as "security" because SHA-pinning is supply-chain defense.

Override if your repo has a different naming convention for security tracking issues. The title must be stable across runs; changing it after the first run leaves an orphan.

#### `signing-method`

Default: empty (unsigned).

How automated commits are cryptographically signed:

- empty — unsigned. Author is set correctly; GitHub renders the commit as "Unverified."
- `ssh` — SSH signing. See [Signing](#signing).
- `gpg` — GPG signing. Supported for repos with existing GPG infrastructure. New setups should prefer SSH.

## Secret-bearing inputs

Composite actions do not have a separate `secrets:` block. Secret values ride in as regular inputs. Always reference them via `${{ secrets.NAME }}` at the call site so GitHub masks the value in logs.

### `gh-pat` — required

A Personal Access Token (classic) or fine-grained PAT with `repo` and `workflow` scopes on the target repo.

Why not `GITHUB_TOKEN`: PRs opened by `GITHUB_TOKEN` do not trigger workflows. Your CI (lint, test, build) will not run on the automated PR, so you won't know if the update broke anything. A PAT from a bot account works around this.

Store as a repo or organization secret and pass via `gh-pat: ${{ secrets.YOUR_PAT_SECRET_NAME }}`.

### `signing-key` — optional

Required when `signing-method` is non-empty. Validated at runtime; the action fails fast if set to `ssh` or `gpg` without a key.

- For `ssh`: the full private key, including the `-----BEGIN OPENSSH PRIVATE KEY-----` header and footer.
- For `gpg`: an armored private key block (`gpg --armor --export-secret-keys <key-id>`).

### `signing-passphrase` — optional

The passphrase protecting `signing-key`. Leave unset if the key is unencrypted.

## Signing

### SSH or GPG

| Aspect | SSH | GPG |
|--------|-----|-----|
| Key format | One `OPENSSH PRIVATE KEY` file | Keyring + key ID + subkeys |
| Persistent agent required | No (`ssh-keygen -p` strips the passphrase in place) | Yes (`gpg-agent` with a preset passphrase) |
| Passphrase handling | Single `ssh-keygen -p` call | `--pinentry-mode loopback` or agent preset |
| Setup steps | 3 (generate, register, store secret) | 5+ (generate, export, register on GitHub, set up agent, configure git) |
| Trust model on GitHub | Public key registered as "Signing Key" on the committer's account | Same, plus expiration and subkey complexity |
| Debugging | `ssh-keygen -Y verify` | `gpg --verify` + keyring state |

SSH signing produces the same "Verified" badge as GPG with substantially less machinery in CI. The GPG path exists for repos that already have GPG infrastructure they don't want to change. New setups should prefer SSH.

### SSH setup (recommended)

One-time, per repo or per organization.

1. **Generate a dedicated signing key** on your workstation. Do not reuse your GitHub auth key.

   ```sh
   ssh-keygen -t ed25519 -f ./bot-signing-key -C "bot-signing-key"
   ```

   Use a passphrase if you want the secret at rest protected. The CI workflow strips it via `ssh-keygen -p` before use.

2. **Register the public key** on the bot account that owns the PAT.
    - GitHub → Settings → SSH and GPG keys → **New SSH key**.
    - **Key type: Signing Key**, not Authentication Key. This distinction matters.
    - Paste `bot-signing-key.pub`.

3. **Store the secrets** in the target repo (or as an organization secret).
    - `SSH_SIGNING_KEY` (or any name) — full content of `bot-signing-key`.
    - `SSH_SIGNING_KEY_PASSPHRASE` — the passphrase you chose. Omit if none.

4. **Reference the secrets** in your caller workflow.

   ```yaml
   with:
     signing-method: ssh
     signing-key: ${{ secrets.SSH_SIGNING_KEY }}
     signing-passphrase: ${{ secrets.SSH_SIGNING_KEY_PASSPHRASE }}
   ```

5. **Verify** by triggering `workflow_dispatch` manually. The resulting commit in the automated PR should display "Verified" with a tooltip naming your bot account.

### GPG setup

> **Note:** the GPG path is implemented but not yet validated end-to-end against a real GPG workflow in production. The SSH path is what the maintainers use. If you set up the GPG path and it works (or does not), open an issue so we can confirm or fix it.

1. **Generate or identify** an existing GPG signing key for the bot account.

   ```sh
   gpg --full-generate-key        # for a new key; choose "RSA and RSA" or "ECC"
   gpg --list-secret-keys --keyid-format=long
   ```

2. **Export the armored private key.**

   ```sh
   gpg --armor --export-secret-keys <key-id> > bot-signing.gpg
   ```

3. **Register the public key** on the bot's GitHub account.
    - Settings → SSH and GPG keys → **New GPG key**.
    - Export with `gpg --armor --export <key-id>` and paste.

4. **Store the secrets** in the target repo (or as an organization secret).
    - `GPG_PRIVATE_KEY` (or any name) — full armored content of `bot-signing.gpg`.
    - `GPG_PASSPHRASE` — the passphrase on the key. Omit if none.

5. **Reference the secrets** in your caller workflow.

   ```yaml
   with:
     signing-method: gpg
     signing-key: ${{ secrets.GPG_PRIVATE_KEY }}
     signing-passphrase: ${{ secrets.GPG_PASSPHRASE }}
   ```

During the run the action imports the key, extracts its key ID, presets the passphrase into `gpg-agent`, and configures `git` with `gpg.format openpgp` and `commit.gpgsign true` for the duration of the job.

### No signing

Leave `signing-method` empty (or omit it). Commits display as "Unverified" in the GitHub UI but the author metadata is still correct. Fine for internal repos where the PR itself, not the commit signature, is the reviewed artifact.

## What's autodetected

You do not pass these. The action reads them from the workflow context.

| Value | Source |
|-------|--------|
| PR base branch | `github.event.repository.default_branch` |
| Repo owner and name | `github.repository` |
| Runner OS | fixed to `ubuntu-latest` |

If your repo's default branch is `trunk` or `develop`, the PR targets that. No input needed.

## Versioning

- Release tags follow strict semver: `v1.0.0`, `v1.0.1`, `v1.0.2`, and so on.
- Consumers pin by commit SHA. See [Quickstart](#quickstart) and [Updating the pin](#updating-the-pin). The comment next to the SHA is the release name. This action rewrites that comment whenever a newer release ships.
- Breaking input-contract changes ship as `v2.0.0`. The `v1.x.y` line stops advancing at that point, so existing consumers are not broken.

## Troubleshooting

**"Input required and not supplied: gh-pat"**

Your caller workflow is missing `gh-pat: ${{ secrets.YOUR_PAT_SECRET_NAME }}` in the `with:` block. Add it.

**"signing-method is 'ssh' but signing-key input is empty"**

Either pass `signing-key` or set `signing-method` to empty.

**PR opens but CI does not run on it**

Your `gh-pat` is actually `GITHUB_TOKEN`. Use a PAT from a bot account. See the `gh-pat` section above.

**Commit shows "Unverified" despite `signing-method: ssh`**

The public key registered on the bot account is marked as an Authentication Key, not a Signing Key. GitHub distinguishes the two. Re-add it with the correct type.

**"Warning: latest release tag '…' is not strict semver, trying tags API"**

This action compares by strict `vX.Y.Z` release tags. When the upstream you are auditing only ships non-semver releases (for example, a release tagged just `latest` or `v1`), the action falls back to the tags API to find the most recent strict-semver tag, and logs this warning while it does. If the fallback also finds nothing, the upstream is silently skipped for that run.

**Action finds zero `uses:` references**

Your workflows may be in `.yaml` files, not `.yml`. Override `scan-globs`.

**"The action X is not allowed in <org>/<repo> because all actions must be pinned to a full-length commit SHA"**

Your repo or GitHub organization has a policy requiring SHA-pinning on every `uses:` reference. The tag form (`@v1.0.2`) is rejected. See [Updating the pin](#updating-the-pin) for how to resolve the commit SHA and pin by hash. Subsequent updates happen automatically.

## License

MIT. See [LICENSE](./LICENSE).
