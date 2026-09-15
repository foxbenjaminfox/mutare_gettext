# mutare_gettext

[![Hex.pm](https://img.shields.io/hexpm/v/mutare_gettext.svg)](https://hex.pm/packages/mutare_gettext)
[![Hexdocs](https://img.shields.io/badge/hexdocs-docs-blue.svg)](https://hexdocs.pm/mutare_gettext)
[![CI](https://github.com/foxbenjaminfox/mutare_gettext/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/foxbenjaminfox/mutare_gettext/actions/workflows/ci.yml)
[![License](https://img.shields.io/hexpm/l/mutare_gettext.svg)](https://github.com/foxbenjaminfox/mutare_gettext/blob/master/LICENSE)

A [Mutare](https://github.com/foxbenjaminfox/mutare) **extension** for
[Gettext](https://hexdocs.pm/gettext) macro expansion and argument routing. It produces no mutations
of its own. It configures Mutare's **built-in** mutators to mutate runtime arguments in a
`use Gettext` module while preserving the literals required to compile the metamutant.

## Install

```elixir
# mix.exs
def deps do
  [
    {:mutare, "~> 0.1", only: [:dev, :test], runtime: false},
    {:mutare_gettext, "~> 0.1", only: [:dev, :test], runtime: false}
  ]
end
```

```elixir
# .mutare.exs
[extensions: [Mutare.Gettext]]
```

## What it does

Gettext (>= 0.26) requires two accommodations for a single-compile mutation tool:

1. **`use Gettext, backend: MyApp.Gettext`** registers its backend by *mutating the caller module*,
   so Mutare's in-process `use` expansion raises before recovering the injected
   `import Gettext.Macros` — leaving bare `gettext`/`ngettext` calls unresolved.
2. A message id (`gettext("Hello")`) must be a **compile-time literal**; splicing a mutation
   selector there causes a macro expansion error and prevents compilation.

The extension fixes both via Mutare's two extension capability behaviours:

- **`Mutare.UseExpansion`** (`expand_use/3`) supplies `import Gettext.Macros` directly for
  every `use Gettext` during Mutare's scan, so the bare calls resolve.
- **`Mutare.CallRouting`** (`call_routes/0`) routes each macro's arguments per position: the **compile-time literals** (message
  id, plural id, domain, context, backend) are `:raw` (left unchanged), while the
  **runtime** arguments — the `ngettext` plural `count` and the interpolation `bindings` — are
  `:expression`, so mutation testing can check whether tests detect changes to plural counts
  and interpolation values.

This uses a whole-module `:raw` baseline plus a per-position override for every arity with a
`count` or `bindings` argument. The overrides are *derived* from the Gettext macro families;
the test suite cross-checks each one against the `Gettext.Macros` exports.

Targets Gettext **>= 0.26**; on older versions the extension has no effect.

## Development

```
mix deps.get
mix test
mix check      # format --check-formatted, credo, dialyzer
```

## License

MIT — see [LICENSE](LICENSE).
