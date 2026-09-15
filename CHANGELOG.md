# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/foxbenjaminfox/mutare_gettext/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/foxbenjaminfox/mutare_gettext/releases/tag/v0.1.0
