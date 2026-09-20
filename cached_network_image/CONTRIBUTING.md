Contributing to CachedNetworkImage
==================================

What you will need
------------------

 * A Linux, macOS or Windows machine (to run and compile the iOS and macOS parts of the example you will need a Mac);
 * git ([installation instructions](https://git-scm.com/));
 * The Flutter SDK, stable channel ([installation instructions](https://docs.flutter.dev/get-started/install));
 * Chrome, to run the web package's tests;
 * JDK 17, if you want to build the Android example;
 * A personal GitHub account ([sign up here](https://github.com/)).

How this repository is laid out
-------------------------------

This is a monorepo holding three published packages plus an example app:

 * `cached_network_image/` — the app-facing package, and the example under `cached_network_image/example/`
 * `cached_network_image_platform_interface/` — the contract shared by the two implementations
 * `cached_network_image_web/` — the web implementation

There is no Melos and no root `pubspec.yaml`, so every command below runs from
inside the package you are changing. A change to the platform interface almost
always has to be applied to both implementations in the same pull request. See
[AGENTS.md](../AGENTS.md) for the architecture and the full development reference.

Setting up your development environment
---------------------------------------

 * Fork `https://github.com/Baseflow/flutter_cached_network_image` into your own GitHub account. If you already have a fork and are moving to a new computer, make sure you update your fork.
 * If you haven't configured your machine with an SSH key that's known to GitHub, follow [GitHub's directions](https://docs.github.com/en/authentication/connecting-to-github-with-ssh) to generate one.
 * Clone your fork: `git clone git@github.com:<your_name_here>/flutter_cached_network_image.git`
 * Change into the directory: `cd flutter_cached_network_image`
 * Add an upstream remote, so that you fetch from the official repository and not your clone: `git remote add upstream git@github.com:Baseflow/flutter_cached_network_image.git`

Running the example project
---------------------------

 * Change into the example directory: `cd cached_network_image/example`
 * Run the app: `flutter run`

Note that running or building the example regenerates some tracked plugin
registrant files. Leave those out of your commit unless the set of plugins
actually changed.

Contribute
----------

We really appreciate contributions via GitHub pull requests. To contribute, take
the following steps:

 * Make sure you are up to date with the latest code on `main`:
   * `git fetch upstream`
   * `git checkout upstream/main -b <name_of_your_branch>`
 * Apply your changes
 * Verify your changes and fix potential warnings and errors, from each package you changed:
   * Check formatting: `dart format <the files you changed>`
   * Run static analysis: `flutter analyze`
   * Run unit tests: `flutter test`, or `flutter test --platform chrome` for `cached_network_image_web`
 * Commit your changes: `git commit -am "<your informative commit message>"`
 * Push changes to your fork: `git push origin <name_of_your_branch>`

Please run `dart format` on the files you changed rather than `dart format .` on
the whole package. The repository has not yet been moved onto the current Dart
formatting style, so a repository-wide format produces a large diff unrelated to
your change.

Send us your pull request:

 * Go to `https://github.com/Baseflow/flutter_cached_network_image` and click the "Compare & pull request" button.

Please make sure you have solved all warnings and errors reported by static
analysis and that you fill in the full pull request template. Failing to do so
will result in us asking you to fix it.
