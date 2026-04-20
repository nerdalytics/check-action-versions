# check-action-versions

Reusable GitHub workflow that audits SHA-pinned action references across consumer repos, resolves each action's latest strict-semver release, and opens security issues + automated PRs when anything is outdated.

Called by consumer repos via:
```yaml
uses: nerdalytics/check-action-versions/.github/workflows/check-action-versions.yml@v1
```

## Quick Commands

| Command | Purpose |
|---------|---------|
| `mise run lint` | Lint all scripts + workflows |
| `mise run format` | Format all scripts (shfmt) |
| `mise run test` | Run bats tests |
| `mise run check` | Lint + format-check + test |

## Architecture

Pure bash. Zero runtime dependencies beyond the standard toolchain on `ubuntu-latest` (`bash`, `jq`, `gh`, `git`, `sed`, `grep`).

- `.github/workflows/check-action-versions.yml` — the reusable workflow (the product)
- `.github/workflows/ci.yml` — dev-hygiene CI for this repo itself
- `scripts/*.sh` — 9 bash scripts invoked sequentially by the reusable workflow
- `tests/*.bats` — bats suite covering deterministic scripts (scan/resolve/compare/apply); integration scripts (issue/PR/commit/close) are validated via parallel pilot in consumer repos, not mocked

## Pipeline

```
checkout → scan-actions → resolve-latest → compare-actions
        → [outdated]    → generate-report → manage-issue → apply-updates
                        → [signing]       → commit-changes → manage-pr
        → [up-to-date]  → close-if-current
```

## Input Contract

See `README.md` for full input/secret reference. Rule of thumb: no caller-opinion defaults. Every value that reveals how a specific consumer is configured must be supplied via `with:` / `secrets:`.

## Release Process

1. Merge changes to `trunk` (PR + green CI required)
2. Tag release: `git tag v1.x.y && git push origin v1.x.y`
3. Move floating major tag: `git tag -f v1 v1.x.y && git push origin v1 --force`
4. Breaking changes bump to `v2`; `v1` stops advancing
