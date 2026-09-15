# mutare_gettext

[![Hex.pm](https://img.shields.io/hexpm/v/mutare_gettext.svg)](https://hex.pm/packages/mutare_gettext)
[![Hexdocs](https://img.shields.io/badge/hexdocs-docs-blue.svg)](https://hexdocs.pm/mutare_gettext)
[![CI](https://github.com/foxbenjaminfox/mutare_gettext/actions/workflows/ci.yml/badge.svg?branch=master)](https://github.com/foxbenjaminfox/mutare_gettext/actions/workflows/ci.yml)
[![License](https://img.shields.io/hexpm/l/mutare_gettext.svg)](https://github.com/foxbenjaminfox/mutare_gettext/blob/master/LICENSE)

A [Mutare](https://github.com/foxbenjaminfox/mutare) **extension** that teaches mutation testing to read
[Gettext](https://hexdocs.pm/gettext). It is an *extension*, not a mutator: it produces no mutations
of its own — it only makes Mutare's **built-in** mutators land correctly on a `use Gettext` module,
without poisoning the single metamutant build.

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

Gettext (>= 0.26) is two problems for a single-compile mutation tool:

1. **`use Gettext, backend: MyApp.Gettext`** registers its backend by *mutating the caller module*,
   so Mutare's in-process `use` expansion raises and never surfaces the `import Gettext.Macros` it
   injects — the bare `gettext`/`ngettext` calls then never resolve.
2. A message id (`gettext("Hello")`) must be a **compile-time literal**; splicing a mutation
   selector there makes the macro raise while expanding and poisons the build.

The extension fixes both via Mutare's two extension capability behaviours:

- **`Mutare.UseExpansion`** (`expand_use/3`) takes over every `use Gettext` and injects
  `import Gettext.Macros`, so the bare calls resolve.
- **`Mutare.CallRouting`** (`call_routes/0`) routes each macro's arguments per position: the **compile-time literals** (message
  id, plural id, domain, context, backend) are `:raw` (never mutated → no poison), while the
  **runtime** arguments — the `ngettext` plural `count` and the interpolation `bindings` — are
  `:expression`, so a stale plural threshold or wrong interpolation value still gets caught.

This is a whole-module `:raw` baseline plus a per-position override for every arity carrying a
`count`/`bindings`. The overrides are *derived* from the Gettext macro families (so a position
can't drift); the package's test cross-checks each one against the real `Gettext.Macros`.

Targets Gettext **>= 0.26**; on older versions it degrades to a harmless no-op.

## Development

```
mix deps.get
mix test
mix check      # format --check-formatted, credo, dialyzer
```

## License

MIT — see [LICENSE](LICENSE).
