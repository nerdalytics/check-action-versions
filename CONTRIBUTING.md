# Contributing to `check-action-versions`

## Dev setup

1. Install [`mise`](https://mise.jdx.dev/)
2. Clone this repo: `git clone https://github.com/nerdalytics/check-action-versions.git`
3. `cd check-action-versions && mise install`
4. `mise run check` — lint, format-check, and run tests

All tools (`gh`, `jq`, `shellcheck`, `shfmt`, `bats`, `actionlint`) are pinned in `mise.toml` and installed by `mise install`.

## Dev loop

- Edit a script: `scripts/foo.sh`
- Lint: `mise run lint` (shellcheck + actionlint)
- Format: `mise run format` (shfmt -w)
- Test: `mise run test` (bats tests/)
- Or all at once: `mise run check`

## Adding tests

Deterministic scripts (inputs and outputs are pure functions of arguments + env) must have bats tests. See `tests/scan-actions.bats` for the template.

Integration scripts (touch `gh` against real GitHub state, `git push`, `git commit`) are not unit-tested. They are validated via the parallel pilot in beacon/tinywhale — see the design spec for the rollout plan.

## Pull requests

1. Branch from `trunk`
2. CI must be green (shellcheck, shfmt, bats, actionlint)
3. Squash merge

## Release process

Merge to `trunk` → tag `v1.x.y` → move floating `v1` tag to new release:

```bash
git checkout trunk && git pull
git tag v1.0.1
git push origin v1.0.1
git tag -f v1 v1.0.1
git push origin v1 --force
```

Breaking changes to the input or secret contract bump to `v2`. The `v1` floating tag stops advancing at that point so existing consumers are not surprised.
