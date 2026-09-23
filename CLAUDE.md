@AGENTS.md

## Claude Code

Everything tool-neutral lives in `AGENTS.md` (imported above). Keep it that way: only add
things here that are specific to Claude Code, and put any new project rule in `AGENTS.md`
so other agents and human contributors pick it up too.

### Tooling in this checkout

- Use the plain `flutter` / `dart` commands in `AGENTS.md`. They are what CI runs and
  what a contributor will have. If this checkout happens to carry a local fvm pin
  (`.fvmrc` is gitignored, so it may or may not) prefix with `fvm`. Do not add one,
  and do not tell anyone they need fvm to work on this repo.
- **Never run `dart format .`**, only `dart format` on the files you changed. The
  repo is still in the pre-3.7 short style under a tall style formatter, so a
  repo-wide format produces hundreds of lines of churn you did not intend.
  `AGENTS.md` explains why. If you catch yourself about to commit a reformat, stop.
- `flutter run` for `cached_network_image/example/` is long-running — ask before
  starting it and don't leave it running in the background. Anything that runs
  `pub get` or a build in the example rewrites tracked plugin registrant files, so
  check `git status` before staging.
- There are three packages, so `cd` into the right one first. A bare `flutter test`
  at the repo root does nothing useful.

### Working style

- Prefer the file tools (Read / Edit / Grep / Glob) over `cat`/`sed`/`grep` in Bash for
  reading and editing repo files.
- The tree is small enough that a targeted `Grep` across the three `lib/` directories
  usually beats a search subagent. Use `Explore` only for genuinely wide questions.
- After changing anything in `cached_network_image_platform_interface/lib/`, grep both
  implementations before calling it done. The platform interface analyzes clean on its
  own while the other two packages are broken.
- Run `/code-review` on the diff before handing work over, and `/security-review` when
  a change touches remote fetching or caller-supplied headers:
  `cached_network_image/lib/src/image_provider/_image_loader.dart` and
  `cached_network_image_web/lib/`, the `HttpGet` render path in particular.

### Commits and PRs

- Follow the PR workflow in `AGENTS.md`, and check the user's access before the
  first push (`gh api repos/Baseflow/flutter_cached_network_image --jq
  .permissions.admin`). For a repository admin, push branches straight to
  `Baseflow/flutter_cached_network_image` and open the PR from there. Do not
  use or create a fork. For anyone else, push to their fork and never to a
  `Baseflow` branch. Never push to `main`. Target `main`.
- Before opening a PR, confirm it touches exactly one package (or, for an
  `ImageLoader` signature change, the interface plus both implementations it
  mirrors) and that you bumped that package's `pubspec.yaml` version and added
  its `CHANGELOG.md` entry.
- End commit messages with:

  ```
  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

- End PR descriptions with:

  ```
  🤖 Generated with [Claude Code](https://claude.com/claude-code)
  ```
