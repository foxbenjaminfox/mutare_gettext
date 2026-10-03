# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.1] - 2026-10-03

### Changed

- Requires Mutare 0.5 (`{:mutare, "~> 0.5.0"}`).

## [0.2.0] - 2026-09-26

### Changed

- **Mutare 0.4.1 or newer is required** (`{:mutare, "~> 0.4.1"}`). The routes themselves
  are unchanged: they were already declared by position, which is how Mutare 0.4.0 reads
  every route.

## [0.1.0] - 2026-09-07

Initial public release.

### Added

- **`use Gettext` expansion override** (`Mutare.UseExpansion`): supplies
  `import Gettext.Macros` directly, so bare `gettext`/`ngettext` calls resolve
  during Mutare's scan without expanding Gettext's `__using__` macro.
- **Macro-argument routing** (`Mutare.CallRouting`): a whole-module `:raw`
  baseline over `Gettext.Macros` — message ids, plural ids, domains, contexts,
  and backends remain unchanged so the metamutant compiles — with per-arity
  overrides that route the runtime `count` and `bindings` positions
  `:expression`, so mutation testing can check whether tests detect changes
  to plural counts and interpolation values.
- Overrides are derived from the Gettext macro families and cross-checked
  against the `Gettext.Macros` exports in the test suite.

Targets Gettext >= 0.26; the extension has no effect on older versions.

[Unreleased]: https://github.com/foxbenjaminfox/mutare_gettext/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/foxbenjaminfox/mutare_gettext/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/foxbenjaminfox/mutare_gettext/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/foxbenjaminfox/mutare_gettext/releases/tag/v0.1.0
