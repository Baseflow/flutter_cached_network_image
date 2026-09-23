# cached_network_image agent instructions

Technical reference for AI agents and contributors developing in this repository.

Process and conduct live in their own files: contribution workflow in
[cached_network_image/CONTRIBUTING.md](cached_network_image/CONTRIBUTING.md), the
[Contributor Covenant Code of Conduct](cached_network_image/CODE_OF_CONDUCT.md)
(report unacceptable behavior to [hello@baseflow.com](mailto:hello@baseflow.com)).
Both sit inside the app-facing package rather than at the repository root.

## Scope and stack

- This repo is the **CachedNetworkImage** monorepo maintained by [Baseflow](https://baseflow.com).
- It contains three published Dart packages plus one example app. Work inside the
  **specific package** you are changing. There is no Melos, no root `pubspec.yaml`
  and no root `analysis_options.yaml`, and none should be added unless the team
  decides to. Every command below needs a `cd` into a package first.
- It is **not a federated plugin** in the registry sense: no `registerWith`, no
  method channels, and no native code in any of the three packages. It does have a
  real platform interface split, resolved at compile time by conditional import.
  See [Architecture overview](#architecture-overview).
- Run Flutter and Dart commands with the same tooling CI uses (`flutter`, `dart`).
  Nothing in this repo requires anything else. If you happen to manage SDK versions
  locally with [fvm](https://fvm.app), prefix commands with `fvm`; that is a
  personal setup choice and is never checked in.

### Prerequisites

- Basic Dart and Flutter knowledge
- A working Flutter SDK installation, stable channel. **No workflow pins a
  version.** All four install Flutter with `subosito/flutter-action@v2` at
  `channel: "stable"`, so CI runs whatever stable resolves to on the day. The only
  floor committed anywhere is the pubspec constraint, `sdk: ^3.12.0` and
  `flutter: '>=3.44.0'`, identical in all three packages.
- Chrome, to run the web package's tests locally
- For running or building the example on iOS/macOS, access to a Mac is required
- Android example builds require JDK 17

### Reference documentation

These are **Dart/Flutter libraries** (an image widget over a file cache), not
federated platform plugins. Prefer official Flutter/Dart docs and this repo's
existing code for hands-on work:

- [Using packages](https://docs.flutter.dev/packages-and-plugins/using-packages)
- [Developing packages & plugins](https://docs.flutter.dev/packages-and-plugins/developing-packages)
- [Conditional imports for platform-specific code](https://docs.flutter.dev/platform-integration/web/web-plugins)
- [Effective Dart](https://dart.dev/effective-dart)
- [pub versioning philosophy](https://dart.dev/tools/pub/versioning)

## Packages in this repo

| Directory | Package | Version | Role |
|---|---|---|---|
| `cached_network_image/` | `cached_network_image` | 4.0.0 | App-facing: the `CachedNetworkImage` widget, `CachedNetworkImageProvider`, `MultiImageStreamCompleter`, and the IO `ImageLoader` |
| `cached_network_image_platform_interface/` | `cached_network_image_platform_interface` | 5.0.0 | The shared contract: `ImageLoader`, `ImageRenderMethodForWeb`, `ErrorListener` |
| `cached_network_image_web/` | `cached_network_image_web` | 2.0.0 | The web `ImageLoader` implementation |
| `cached_network_image/example/` | `example` (`publish_to: none`) | 1.0.0+1 | Demo app, all six platform folders committed |

Dependency graph:

```
cached_network_image
  ├─ cached_network_image_platform_interface ^5.0.0
  ├─ cached_network_image_web ^2.0.0
  ├─ flutter_cache_manager ^3.4.1
  ├─ octo_image ^2.1.0
  └─ material_ui ^1.0.0

cached_network_image_web
  ├─ cached_network_image_platform_interface ^5.0.0
  ├─ flutter_cache_manager ^3.4.1
  ├─ web ^1.0.0
  └─ material_ui ^1.0.0

cached_network_image_platform_interface
  ├─ flutter_cache_manager ^3.4.1
  └─ material_ui ^1.0.0
```

Three things this graph does not say out loud:

- **`material_ui` is the official Material library from `flutter/packages`.** It
  replaced `package:flutter/material.dart` across all three packages for Wasm
  compatibility, and it is what raised the floor to Dart 3.12 / Flutter 3.44 and
  made 4.0.0, 5.0.0 and 2.0.0 breaking releases. Do not "restore"
  `package:flutter/material.dart`.
- **Download, disk cache, TTL, eviction and cache metadata belong to
  [`flutter_cache_manager`](https://github.com/Baseflow/flutter_cache_manager)**,
  a sibling Baseflow repository that all three packages depend on. Bugs in any of
  those are filed and fixed there, not here.
- **`sqflite` and `path_provider` are in no pubspec here.** They arrive
  transitively through `flutter_cache_manager`. The only visible trace is the
  example's generated macOS registrant, which makes it look as though this repo
  has native plugin code. It does not: no package here has an `android/`, `ios/`
  or `macos/` directory.

## Architecture overview

```
CachedNetworkImage (widget)          cached_network_image/lib/src/cached_image_widget.dart
  → OctoImage                        (octo_image, phases and cross-fades)
  → CachedNetworkImageProvider       cached_network_image/lib/src/image_provider/cached_network_image_provider.dart
      → ImageLoader                  chosen at compile time, see below
      → MultiImageStreamCompleter    cached_network_image/lib/src/image_provider/multi_image_stream_completer.dart
  → BaseCacheManager                 (flutter_cache_manager, external)
```

### The platform interface contract

This is the part most likely to be broken by accident. `ImageLoader` is selected
by a conditional import in `cached_network_image_provider.dart`:

```dart
import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart'
    if (dart.library.io) '_image_loader.dart'
    if (dart.library.js_interop) 'package:cached_network_image_web/cached_network_image_web.dart'
    show ImageLoader;
```

So there are **three** `ImageLoader` classes:

| Where | Which |
|---|---|
| `cached_network_image_platform_interface/lib/cached_network_image_platform_interface.dart` | the contract, and the fallback when neither `dart.library.io` nor `dart.library.js_interop` is available |
| `cached_network_image/lib/src/image_provider/_image_loader.dart` | IO: android, ios, macos, windows, linux |
| `cached_network_image_web/lib/cached_network_image_web.dart` | web |

Selection is **compile time, not runtime**. There is no registration step, no
`registerWith`, and nothing to add to a `plugins:` block. Do not add one.

**The rule that follows:** a change to a method signature on `ImageLoader` is a
breaking change to two other packages and must be applied to all three in the same
pull request. A signature edited only in `cached_network_image_platform_interface`
analyzes clean there and breaks the other two, which nothing in that package's own
CI job will catch.

`loadBufferAsync` is `@Deprecated('Use loadImageAsync instead')` but is still
overridden in all three. Keep both mirrored until a coordinated removal.

`cached_network_image_web` has its own inner conditional import
(`src/create_image_codec_from_url_stub.dart` against
`src/create_image_codec_from_url_web.dart`, gated on `dart.library.ui_web`). Its
only job is to let the web package compile and analyze on the VM, which is what
CI does. Do not simplify it away.

Persistence and durability are `flutter_cache_manager`'s concern, not this repo's.

## Authoritative project structure

- Root overview: `README.md`. **`cached_network_image/README.md` is a separate
  file**, not a symlink, and it is the one pub.dev shows. They have drifted; a
  user-facing docs change usually means editing both.
- Contribution workflow: `cached_network_image/CONTRIBUTING.md`
- Code of Conduct: `cached_network_image/CODE_OF_CONDUCT.md`
- App-facing exports: `cached_network_image/lib/cached_network_image.dart`
- Widget: `cached_network_image/lib/src/cached_image_widget.dart`
- Provider and conditional import: `cached_network_image/lib/src/image_provider/cached_network_image_provider.dart`
- IO loader: `cached_network_image/lib/src/image_provider/_image_loader.dart`
- Multi-frame completer: `cached_network_image/lib/src/image_provider/multi_image_stream_completer.dart`
- The contract: `cached_network_image_platform_interface/lib/cached_network_image_platform_interface.dart` (one file, the whole package)
- Web loader: `cached_network_image_web/lib/cached_network_image_web.dart` and `cached_network_image_web/lib/src/`
- Example app: `cached_network_image/example/`
- Lints: **four byte-identical `analysis_options.yaml`**, one in each package and
  one in the example. Each is `include: package:flutter_lints/flutter.yaml` plus an
  `analyzer.exclude` list of platform folders. There is no root file to inherit
  from, so a lint change means editing all four.
- CI: see the table below.

### CI map

| Workflow | Package | Jobs | Publish tag |
|---|---|---|---|
| `.github/workflows/app_facing_package.yaml` | `cached_network_image` | format, analyze, tests (`--coverage`), plus example builds for android, ios, macos, windows, linux, web | `v*` |
| `.github/workflows/platform_interface.yaml` | `cached_network_image_platform_interface` | format, analyze, tests (`--coverage`) | `interface-v*` |
| `.github/workflows/platform_web.yaml` | `cached_network_image_web` | format, analyze. **The tests job is commented out.** | `web-v*` |
| `.github/workflows/web.yaml` | `cached_network_image_web` | format, analyze, tests (`flutter test --platform chrome`, on macos) | none |

Two consequences worth knowing before you rely on CI:

- **The web package publishes without running tests.** `platform_web.yaml`'s
  publish job is gated on `needs: [format, analyze]` only, because its tests job is
  commented out. The single thing that ever executes those tests is `web.yaml`,
  which has no publish job. Run the web tests by hand before tagging `web-v*`.
- `web.yaml` and `platform_web.yaml` both fire on `cached_network_image_web/**`,
  so every web pull request runs format and analyze twice.

All four workflows are `branches: [main]`. A pull request targeting any other
branch gets no CI at all.

## Where to make changes

| Change | Goes in |
|---|---|
| Widget API, placeholder, error widget, fade behavior | `cached_network_image/lib/src/cached_image_widget.dart` |
| Provider lifecycle, cache key, `evictImage` | `cached_network_image/lib/src/image_provider/cached_network_image_provider.dart` |
| IO fetch, decode and resize | `cached_network_image/lib/src/image_provider/_image_loader.dart` |
| Web fetch and decode, `HtmlImage` against `HttpGet` | `cached_network_image_web/lib/` |
| Any type shared by IO and web | `cached_network_image_platform_interface/lib/`, **and mirrored into both implementations in the same PR** |
| Download, disk cache, TTL, eviction, cache metadata | `Baseflow/flutter_cache_manager`, not here |

**One package per pull request.** Scope every PR to a single package — its
`pubspec.yaml` version bump and `CHANGELOG.md` entry travel with it in the same
PR (see [Pull request workflow](#pull-request-workflow)). The only exception is
a signature change to `ImageLoader`: that one still has to land in
`cached_network_image_platform_interface` and both implementations in the same
PR, per the row above, because nothing in either package's own CI job would
catch the other half breaking. When a PR is that exception, bump the version
and `CHANGELOG.md` for every package it touches, and update the sibling
version constraint in the dependents' `pubspec.yaml` to match.

Things to know before changing the loaders:

- **Resizing silently does nothing on a plain cache manager.** `_image_loader.dart`
  asserts `cacheManager is ImageCacheManager || (maxWidth == null && maxHeight ==
  null)`, and outside that assert `maxWidth` and `maxHeight` are simply ignored.
  Keep the assert and the branch below it in step.
- **Never put web-only code in `cached_network_image/lib/`**, or IO-only code in
  `cached_network_image_web/lib/`.
- **Never add a dependency to `cached_network_image_platform_interface`** that the
  other two do not already carry. It is the narrowest package and everything
  downstream inherits whatever it takes on.
- **Never `import 'package:flutter/material.dart'`.** Use
  `package:material_ui/material_ui.dart`.

Keep changes minimal in scope, one concern per change, and match existing naming
and testing patterns.

## Development setup

Baseflow's open-source forking workflow:

1. Fork `https://github.com/Baseflow/flutter_cached_network_image` on GitHub.
2. Clone your fork: `git clone git@github.com:<your_name>/flutter_cached_network_image.git`
3. Add upstream (the official repo you fetch from, not your fork):

```bash
git remote add upstream git@github.com:Baseflow/flutter_cached_network_image.git
```

4. Branch from latest `main`:

```bash
git fetch upstream
git checkout upstream/main -b <name_of_your_branch>
```

Expected remotes after setup:

```
origin    git@github.com:<your_name>/flutter_cached_network_image.git   # your fork (push here)
upstream  git@github.com:Baseflow/flutter_cached_network_image.git      # official repo (fetch here)
```

`cached_network_image/CONTRIBUTING.md` still tells you to branch from
`upstream/develop` and to check formatting with `flutter format .`. Both are
wrong; this file is the one to follow.

## Commands

Run from the package you are editing.

```bash
cd cached_network_image          # or cached_network_image_platform_interface
flutter pub get
dart format <the files you changed>
flutter analyze
flutter test
```

The web package's tests need a browser, which is what CI gives them:

```bash
cd cached_network_image_web
flutter pub get
flutter analyze
flutter test --platform chrome
```

Run the example app:

```bash
cd cached_network_image/example
flutter run
```

CI runs format, analyze and test with stricter flags:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test --coverage
```

**Do not run `dart format .`.** The source is still in the pre-3.7 short style
while the pubspecs declare `sdk: ^3.12.0`, which selects the tall style formatter,
so a repo-wide format rewrites files you never touched. Format the files you
changed by name. Bringing the repo onto the current style is worth doing, but as
its own pull request with nothing else in it.

Before finishing work, run analyze and test for every package you touched, plus
both implementations if you changed the platform interface.

### Working across packages locally

`cached_network_image` depends on its siblings by published version, not by path,
and `**/pubspec_overrides.yaml` is gitignored. So `flutter pub get` resolves the
**published** interface, not your local edits, and a cross-package change will
look fine locally while being broken in fact.

To test a change that spans packages, create
`cached_network_image/pubspec_overrides.yaml`:

```yaml
dependency_overrides:
  cached_network_image_platform_interface:
    path: ../cached_network_image_platform_interface
  cached_network_image_web:
    path: ../cached_network_image_web
```

It is gitignored deliberately. Never commit it, and never `git add -f` it. Delete
it before running `dart pub publish --dry-run`, which warns when an override is
present. CI has no overrides, so a green local run with them proves the three
packages agree with each other, not that the published graph resolves.

## Testing expectations

| Package | Tests | Run by |
|---|---|---|
| `cached_network_image` | `test/`: four test files covering the provider, the widget, the stream completer and the image cache manager, plus three helpers | `app_facing_package.yaml`, `flutter test --coverage` |
| `cached_network_image_platform_interface` | one file, asserting the default `ImageLoader` throws | `platform_interface.yaml`, `flutter test --coverage` |
| `cached_network_image_web` | one file | **only** `web.yaml`, `flutter test --platform chrome` |

- **`mocktail` is the only mocking tool**, and only in the app-facing package.
  There is no `build_runner`, no `mockito` and no generated `.mocks.dart` anywhere,
  so nothing here needs a codegen step. Do not introduce one for a test.
- There is **no `integration_test/` and there are no golden tests.** Do not add a
  golden without a decision first; there is no CI job that would update one.
- **`cached_network_image/test/rendering_tester.dart` is a vendored copy of
  Flutter's own test harness** and mirrors framework internals. It is the first
  thing that breaks when Flutter stable moves; 4.0.0 already carries a fix to it.
  When tests fail after an SDK bump, suspect this file before the library.
- The web and platform interface tests each carry their own hand-written
  `MockCacheManager implements BaseCacheManager`. They are near duplicates, so a
  method added to `BaseCacheManager` upstream stops both compiling.
- Prefer the in-memory fakes and `package:file`'s memory file system over real
  disk or network.

## Platform notes

- **IO (android, ios, macos, windows, linux):** `_image_loader.dart`. Resizing
  requires the cache manager to be an `ImageCacheManager`; see the assert noted
  above.
- **Web:** `cached_network_image_web`. `ImageRenderMethodForWeb.HtmlImage` is the
  default and gets browser caching but cannot send custom headers. `HttpGet`
  sends headers and loses browser caching. Changing the default is a breaking
  change for anyone relying on either property.
- **Wasm:** the reason `material_ui` is a dependency. Do not reintroduce
  `dart:html` or `package:flutter/material.dart`.
- **The example commits all six platform folders**, and several generated plugin
  registrant files under `linux/`, `macos/` and `windows/` are tracked. Running
  `flutter pub get` or a build in the example rewrites them. Review that diff and
  drop it unless the plugin set genuinely changed. Never `git add -A` after
  running the example.

## Pull request workflow

**`main` is the branch of record.** Fork from `upstream/main`, open every pull
request against `main`, and rebase onto `main` before submitting. All four
workflows build `main` only, so a pull request against anything else gets no CI.
`origin/develop` is a leftover from an earlier branch layout: it is not
maintained, and must not be branched from or targeted.

This repo uses the **forking workflow**: contributors work on their own fork and
open pull requests to the main repository. Maintainers review and merge; do not
push directly to `Baseflow/flutter_cached_network_image`.

1. Apply changes on a branch based on `upstream/main`, scoped to one package
   per the rule above.
2. Bump that package's `version:` in `pubspec.yaml` following semver, and add a
   matching `## [x.y.z] - YYYY-MM-DD` `CHANGELOG.md` entry describing the
   change (format: see [Releases](#releases)). Date it with the day you open
   the PR; a maintainer will correct it if it slips before tagging.
3. Verify locally, from each package you changed:
   - `dart format <the files you changed>`
   - `flutter analyze`
   - `flutter test` (`flutter test --platform chrome` for the web package)
4. Push to your fork: `git push origin <name_of_your_branch>`
5. Open a pull request against `main` on `Baseflow/flutter_cached_network_image`
   and fill out the full [PR template](.github/PULL_REQUEST_TEMPLATE.md).

Keep public API changes additive and non-breaking where possible; breaking changes
need a clear major-version plan and README/CHANGELOG callouts.

### PR description style

**Hard requirement**: use the [PR template](.github/PULL_REQUEST_TEMPLATE.md)'s
actual section headings verbatim, emoji shortcodes included:
`### :sparkles: What kind of change does this PR introduce? (Bug fix, feature, docs update...)`,
`### :arrow_heading_down: What is the current behavior?`,
`### :new: What is the new behavior (if this is a feature change)?`,
`### :boom: Does this PR introduce a breaking change?`,
`### :bug: Recommendations for testing`,
`### :memo: Links to relevant issues/docs`, and
`### :thinking: Checklist before submitting` with its four items. Do not
substitute a different structure, even for small or maintainer-authored pull
requests such as release and version-bump ones.

Fill out the template, but keep each section tight:

- State what changed and why. Don't narrate your own editing process, and don't
  explain why one obvious, in-scope edit was made alongside another.
- Don't repeat file paths in prose; the diff already shows them.
- Answer yes/no questions with a plain yes/no; add a sentence only when the answer
  is non-obvious. "Does this PR introduce a breaking change?" is the exception:
  answer "No" alone when it is not, but when it is, say what breaks and for whom.
- Keep "Recommendations for testing" to what a reviewer needs to act on: what ran,
  what did not and why, and what to check on CI.

### PR checklist

The repository's own template checklist:

- [ ] All projects build
- [ ] Follows style guide lines
- [ ] Relevant documentation was updated
- [ ] Rebased onto current `develop` — **read this as `main`.** The template is
      stale; `main` is the branch of record. Do not rebase onto `develop`, and do
      not rewrite the template item inside an unrelated pull request.

And for this repo specifically:

- [ ] This PR touches exactly one package — or, for an `ImageLoader` signature
      change, the platform interface and both implementations it must mirror
- [ ] If `analysis_options.yaml` changed, all four copies changed
- [ ] No `pubspec_overrides.yaml` in the diff, and no regenerated example plugin
      registrant files unless the plugin set actually changed
- [ ] `pubspec.yaml` version bumped and `CHANGELOG.md` updated for every
      package this PR changes
- [ ] Public API documented with `///` doc comments where applicable
- [ ] New tests added where applicable; all tests pass

## Releases

Each package is versioned and released independently, but they do not release
independently of each other. Only maintainers cut releases.

| Package | Tag | Workflow |
|---|---|---|
| `cached_network_image_platform_interface` | `interface-vX.Y.Z` | `platform_interface.yaml` |
| `cached_network_image_web` | `web-vX.Y.Z` | `platform_web.yaml` |
| `cached_network_image` | `vX.Y.Z` | `app_facing_package.yaml` |

**The order is fixed: platform interface, then web, then app-facing.** Every
publish job starts by resolving from pub.dev, so a package can only be tagged once
everything it depends on is live there. Never push all three tags at once: the two
downstream workflows will start immediately and fail to resolve siblings that are
not published yet.

1. Confirm `main` is ready. Under the one-package-per-PR rule, every merged PR
   already bumped its own package's `version:` and added its `CHANGELOG.md`
   entry (see [Pull request workflow](#pull-request-workflow)) — there is no
   separate release-prep PR to land first. Before tagging, check that the
   sibling constraints in `cached_network_image/pubspec.yaml` and
   `cached_network_image_web/pubspec.yaml` were bumped to match wherever a
   dependency they pin took a new major version. A release that raises the
   Dart or Flutter floor is breaking for all three and needs all three bumped
   together in one coordinated PR.
2. Verify from each package directory, with any `pubspec_overrides.yaml` deleted:
   `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`
   (`--platform chrome` for the web package), and `dart pub publish --dry-run`.
   The app-facing dry run only passes once the siblings are published, so re-run
   it after step 4.
3. Tag `interface-vX.Y.Z` on the merge commit on `main`. Push. Wait for the
   workflow to go green and for the version to be resolvable on pub.dev.
4. Run the web tests by hand, then tag `web-vX.Y.Z`. Push, and wait again.
   Tagging the web package runs no tests, for the reason in the CI map above.
5. Tag `vX.Y.Z`. Push. This is the heaviest workflow: format, analyze, tests and
   six example platform builds all gate the publish.

**Pushing the tag is what publishes.** The workflows run `dart pub publish` via
pub.dev OIDC trusted publishing, gated on `github.ref_type == 'tag'`. They do not
bump versions and do not edit changelogs. Never run `dart pub publish` by hand,
and never bump a version without a tag to match.

`CHANGELOG.md` today uses `## [x.y.z] - YYYY-MM-DD` headings with `### Breaking
changes` and `### Other changes` subsections and `*` bullets, and no
`## [Unreleased]` section. Match that format. When you add your own entry in a
pull request, date it with the day you open the PR — a maintainer will correct
the date if it changes before the version is actually tagged. Introducing an
`[Unreleased]` section is a separate decision, not something to do as part of
an unrelated change.

Published versions are immutable, so keep branch names out of URLs in
`pubspec.yaml` and in docs: a branch-specific link becomes a permanent dead link
once that branch is gone.
