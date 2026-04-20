# Check Action Versions

A composite GitHub Action that audits the `uses:` references in your workflow files, resolves each action's latest strict-semver release, and opens a security issue + automated PR when anything is outdated.

- Runs on your schedule (weekly is typical)
- Creates a single tracking issue, updates it on each run
- Produces a CI-triggering PR (optionally SSH or GPG-signed) with the SHA and tag updates applied
- Auto-closes the issue and PR when every action is back on its latest release

## Quickstart

Add this to any repo you want audited. The action is pinned by commit SHA — the same form this action will produce for every other entry in your workflow files, and the form required by any repo or org with a strict supply-chain policy.

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

That's the minimum. Everything else is optional — see below.

The SHA shown above pins `v1.0.2`. For every subsequent release, this action itself will open a PR in your repo rewriting the pin to the new SHA + the new exact release name. See [Updating the pin](#updating-the-pin) below if you ever need to do it manually.

## Updating the pin

This action auto-maintains the pin in your workflow files — when a new `check-action-versions` release ships, a scheduled run will open a PR bumping the SHA + release comment to the new values. You almost never need to do this by hand.

If you do (initial install, or you've disabled the scheduled audit), resolve the current latest-release commit SHA:

**Via the GitHub UI:**

1. Open the [Releases page](https://github.com/nerdalytics/check-action-versions/releases)
2. Click the release you want (typically the latest)
3. The commit SHA appears in the header; click it to see the full 40-character hash

**Via `gh` CLI:**

```sh
# Commit SHA for a specific release tag
gh api repos/nerdalytics/check-action-versions/commits/v1.0.2 --jq .sha
```

Paste the SHA into your `uses:` line with the release name as a comment:

```yaml
      - uses: nerdalytics/check-action-versions@<40-char-commit-sha> # v1.0.2
```

The comment is documentation only — GitHub resolves the action at the SHA. Both humans reading the file and this action's own update logic use the comment to confirm which release a given SHA corresponds to.

## Permissions

Your caller workflow needs `contents: write`, `issues: write`, `pull-requests: write`. Declare at workflow or job level.

```yaml
permissions:
  contents: write
  issues: write
  pull-requests: write
```

## Inputs

### Required

#### `committer-name`
Git `user.name` on the automated commit. Must be supplied because there is no sensible fallback — using your personal identity for bot commits is the wrong behavior, and using `github-actions[bot]` silently would look wrong in your repo's history if you expect a specific author.

#### `committer-email`
Git `user.email` on the automated commit. Use a `noreply.github.com` address tied to the bot account that owns the PAT, so the commit's author is visually consistent with the PR author and the "Verified" badge (if signed) resolves to the correct account.

### Optional

#### `commit-prefix`
Default: empty

Prepended to both the commit message and the PR title.

Examples:
- `chore(core):` — Conventional Commits with a `core` scope
- `build(deps):` — Conventional Commits, what Dependabot emits
- `ci:` — short form
- empty — plain prose (commit reads `Update N GitHub Action(s) to latest versions`)

Reason for no default: Conventional Commits is a convention, not a rule. Repos that use plain prose would see every automated commit polluted with a prefix they don't use. If you use Conventional Commits, supply the prefix you want; otherwise leave empty.

#### `scan-globs`
Default: `.github/workflows/*.yml`

Newline-separated list of globs telling the action which files to scan for `uses:` references.

Override if:
- Your repo has `.yaml` (not `.yml`) workflow files: add `.github/workflows/*.yaml`
- Your repo ships a composite action: add `action.yml` or `**/action.yml`

Reason for default: this glob matches GitHub's own universal workflow location — defaulting to it leaks nothing about any specific repo's setup.

#### `branch-name`
Default: `update-github-actions`

Branch name for the automated PR. The branch is deleted and recreated on each run that has changes, so a stable name is fine.

Override if:
- You're running two parallel callers (e.g., during migration — use a `-v2` suffix for the pilot)
- Your repo has a branch-naming convention you want enforced

#### `outdated-behavior`
Default: `both`

What happens when the scan finds outdated actions:
- `both` — create/update a tracking issue **and** open a PR with the fixes (recommended default; most visible, most actionable)
- `pr-only` — open a PR, no issue
- `issue-only` — create/update the issue, no PR (humans apply the fixes manually — safer for repos without a bot PAT)
- `dry-run` — log findings, do nothing else (observation phase, first few weeks after adopting)

#### `up-to-date-behavior`
Default: `close`

What happens when every action is current:
- `close` — close the tracking issue and any open automated PR (recommended; signals cleanly that the alert is resolved)
- `keep` — leave them open (useful if humans are mid-review)
- `silent` — no-op

#### `pr-labels`
Default: empty

Comma-separated labels applied to the automated PR. Example: `security,dependencies`. Labels must already exist in your repo — the action does **not** create them (explicit is better than magic).

#### `issue-labels`
Default: empty

Same as above, for the tracking issue.

#### `issue-title`
Default: `Security: Outdated GitHub Actions detected`

The fixed title the action uses to find its own issue across runs (so it can update instead of creating a duplicate). Framed as "security" because SHA-pinning is supply-chain defense.

Override if your repo has a different naming convention for security tracking issues. Must be stable across runs — changing it after the first run creates an orphan.

#### `signing-method`
Default: empty (unsigned)

How automated commits are cryptographically signed:
- empty — unsigned. Simplest. Commit author is set correctly; commit appears as "Unverified" in the GitHub UI.
- `ssh` — SSH signing. Recommended when you want verified commits. See [Signing](#signing) below.
- `gpg` — GPG signing. Supported for repos with existing GPG infrastructure, but SSH is simpler to set up and maintain.

## Secret-bearing inputs

Composite actions don't have a separate `secrets:` block — secret values are passed as regular inputs. Always reference them via `${{ secrets.NAME }}` at the call site so GitHub masks the value in logs.

### `gh-pat` — required

A Personal Access Token (classic) or fine-grained PAT with `repo` and `workflow` scopes on the target repo.

**Why not `GITHUB_TOKEN`?** PRs opened by `GITHUB_TOKEN` do not trigger workflows. Your CI (lint, test, build) will not run on the automated PR, so you won't know if the update broke anything. A PAT from a bot account works around this.

Store as a repo or org secret and pass via `gh-pat: ${{ secrets.YOUR_PAT_SECRET_NAME }}`.

### `signing-key` — optional

Required iff `signing-method` is non-empty. Validated at runtime; the action fails fast with a clear error if set to `ssh` or `gpg` without a key.

- For `ssh`: the full private key including the `-----BEGIN OPENSSH PRIVATE KEY-----` header and footer
- For `gpg`: an armored private key block (`gpg --armor --export-secret-keys <key-id>`)

### `signing-passphrase` — optional

The passphrase protecting `signing-key`. Leave unset if the key is unencrypted.

## Signing

### Why SSH over GPG (when you want signatures at all)

| Aspect | SSH | GPG |
|--------|-----|-----|
| Key format | One `OPENSSH PRIVATE KEY` file | Keyring + key ID + subkeys |
| Persistent agent required | No (`ssh-keygen -p` strips passphrase in place) | Yes (`gpg-agent` with preset passphrase) |
| Passphrase handling | Single `ssh-keygen -p` call | `--pinentry-mode loopback` or agent preset |
| Setup steps | 3 (generate, register, store secret) | 5+ (generate, export, register on GitHub, set up agent, configure git) |
| Trust model on GitHub | Public key registered as "Signing Key" on committer's account | Same, plus expiration/subkey complexity |
| Debugging | `ssh-keygen -Y verify` | `gpg --verify` + keyring state |

SSH signing gives you the same "Verified" badge as GPG with substantially less moving machinery in CI. GPG exists in this action for repos that already have GPG infrastructure they don't want to change; new setups should prefer SSH.

### SSH setup (recommended)

One-time, per repo or per org:

1. **Generate a dedicated signing key** on your workstation. Do not reuse your GitHub auth key.
   ```sh
   ssh-keygen -t ed25519 -f ./bot-signing-key -C "bot-signing-key"
   ```
   Use a passphrase if you want the secret-at-rest protected; the CI workflow will strip it via `ssh-keygen -p` before use.

2. **Register the public key** on the bot account that owns the PAT:
    - GitHub → Settings → SSH and GPG keys → **New SSH key**
    - **Key type: Signing Key** (not Authentication Key — this is the critical distinction)
    - Paste `bot-signing-key.pub`

3. **Store the secrets** in the target repo (or an org-level secret):
    - `SSH_SIGNING_KEY` (or whatever name you prefer) — full content of `bot-signing-key`
    - `SSH_SIGNING_KEY_PASSPHRASE` — the passphrase you chose (omit if none)

4. **Reference the secrets** in your caller workflow:
   ```yaml
   with:
     signing-method: ssh
     signing-key: ${{ secrets.SSH_SIGNING_KEY }}
     signing-passphrase: ${{ secrets.SSH_SIGNING_KEY_PASSPHRASE }}
   ```

5. **Verify** by triggering `workflow_dispatch` manually. The resulting commit in the automated PR should display "Verified" with a tooltip naming your bot account.

### GPG setup

> **Note:** the GPG path in this action is implemented but has not been end-to-end validated against a real GPG workflow in production. The SSH path above is what the maintainers use. If you set up the GPG path and it works (or doesn't), please open an issue so we can confirm or fix it.

1. **Generate or identify** an existing GPG signing key for the bot account:
   ```sh
   gpg --full-generate-key        # for a new key; choose "RSA and RSA" or "ECC"
   gpg --list-secret-keys --keyid-format=long
   ```

2. **Export the armored private key:**
   ```sh
   gpg --armor --export-secret-keys <key-id> > bot-signing.gpg
   ```

3. **Register the public key** on the bot's GitHub account:
    - Settings → SSH and GPG keys → **New GPG key**
    - Export with `gpg --armor --export <key-id>` and paste

4. **Store the secrets** in the target repo (or an org-level secret):
    - `GPG_PRIVATE_KEY` (or any name) — full armored content of `bot-signing.gpg`
    - `GPG_PASSPHRASE` — the passphrase on the key (omit if none)

5. **Reference the secrets** in your caller workflow:
   ```yaml
   with:
     signing-method: gpg
     signing-key: ${{ secrets.GPG_PRIVATE_KEY }}
     signing-passphrase: ${{ secrets.GPG_PASSPHRASE }}
   ```

During the run the action imports the key, extracts its key ID, presets the passphrase into `gpg-agent`, and configures `git` with `gpg.format openpgp` + `commit.gpgsign true` for the duration of the job.

### No signing

Leave `signing-method` empty (or omit). Commits will show as "Unverified" in the GitHub UI but the author metadata is still correct. Fine for internal repos where the PR itself (not the commit signature) is the reviewed artifact.

## What's autodetected

You do not pass these — the action reads them from the workflow context:

| Value | Source |
|-------|--------|
| PR base branch | `github.event.repository.default_branch` |
| Repo owner/name | `github.repository` |
| Runner OS | fixed to `ubuntu-latest` |

If your repo's default branch is `trunk` or `develop`, the PR targets that — no input needed.

## Versioning

- Release tags `v1.0.0`, `v1.0.1`, `v1.0.2`, …
- Consumers pin by commit SHA — see [Quickstart](#quickstart) and [Updating the pin](#updating-the-pin). The comment next to the SHA is the release name, which this action's own update logic rewrites whenever a newer release ships.
- Breaking input-contract changes ship as `v2.0.0`; the `v1.x.y` line stops advancing at that point so existing consumers are not broken.

## Troubleshooting

**"Input required and not supplied: gh-pat"**
Your caller workflow is missing `gh-pat: ${{ secrets.YOUR_PAT_SECRET_NAME }}` in the `with:` block. Add it.

**"signing-method is 'ssh' but signing-key input is empty"**
Either pass `signing-key` or set `signing-method` to empty.

**PR opens but CI doesn't run on it**
`gh-pat` is actually `GITHUB_TOKEN`. Use a PAT from a bot account — see the `gh-pat` section above.

**Commit shows "Unverified" despite `signing-method: ssh`**
The public key registered on the bot account is marked as an Authentication Key, not a Signing Key. GitHub distinguishes the two. Re-add it with the correct type.

**"Warning: latest release tag '…' is not strict semver, trying tags API"**
This action compares by strict `vX.Y.Z` release tags. When the upstream you're auditing only ships non-semver releases (for example, a release tagged just `latest` or `v1`), the action falls back to the tags API to find the most recent strict-semver tag, and logs this warning while it does. If the fallback also finds nothing, the upstream is silently skipped for that run.

**Action finds zero `uses:` references**
Your workflows may be in `.yaml` files, not `.yml`. Override `scan-globs`.

**"The action X is not allowed in <org>/<repo> because all actions must be pinned to a full-length commit SHA"**
Your repo or GitHub org has a policy requiring SHA-pinning on every `uses:` reference. The tag form (`@v1.0.2`) is rejected. See [Updating the pin](#updating-the-pin) for how to resolve the commit SHA and pin by hash. Subsequent updates happen automatically.

## License

MIT — see [LICENSE](./LICENSE).
