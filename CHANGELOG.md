# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 - Unreleased

Initial public release.

### Added

- **`use Gettext` expansion override** (`Mutare.UseExpansion`): injects the
  `import Gettext.Macros` that Gettext's `__using__` would, so bare
  `gettext`/`ngettext` calls resolve inside Mutare's scan instead of raising.
- **Macro-argument routing** (`Mutare.CallRouting`): a whole-module `:raw`
  baseline over `Gettext.Macros` — message ids, plural ids, domains, contexts,
  and backends stay compile-time literals, never poisoning the metamutant
  build — with per-arity overrides that route the runtime `count` and
  `bindings` positions `:expression`, so stale plural thresholds and wrong
  interpolation values are still caught.
- Overrides are derived from the Gettext macro families and cross-checked
  against the real `Gettext.Macros` exports in the test suite.

Targets Gettext >= 0.26; degrades to a harmless no-op on older versions.
