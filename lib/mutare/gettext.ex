defmodule Mutare.Gettext do
  @moduledoc """
  A Mutare **extension** for [Gettext](https://hexdocs.pm/gettext) macro expansion and argument
  routing. It configures the built-in mutators to mutate runtime arguments in a `use Gettext`
  module while preserving the literals required to compile the metamutant.

  It produces no mutations, occupies no mutator slot, and does not appear in reports.
  List it under `:extensions` (in `.mutare.exs` or `Mutare.run/2`):

      # .mutare.exs
      [extensions: [Mutare.Gettext]]

  ## What it does

  The extension implements two capability behaviours (see `Mutare.Extension`):

    * **`c:Mutare.UseExpansion.expand_use/3`** — supplies `import Gettext.Macros` directly for
      every `use Gettext` during Mutare's scan. Gettext (>= 0.26) compiles
      `use Gettext, backend: MyApp.Gettext` by *mutating the caller module* to register the backend,
      which raises when Mutare expands it in the scan process (the caller is already compiled), so
      `import` is not recovered and the bare `gettext`/`ngettext` calls remain unresolved. (The
      `backend:` value is a module alias, not a compile-time literal, so Mutare's requirement for
      static-literal options would prevent expansion regardless.) Supplying the import directly
      allows Mutare to resolve and route those calls.

    * **`c:Mutare.CallRouting.call_routes/0`** — routes each Gettext macro's arguments. The **compile-time
      literal** positions — message id, plural id, domain, context, backend — must never be mutated:
      inserting a mutation selector there causes a macro expansion error and prevents compilation.
      The **runtime** positions — the `ngettext` plural `count` and the interpolation `bindings` —
      *are* mutated, so mutation testing can check whether tests detect changes to plural counts
      and interpolation values.

  This is expressed as a whole-module `:raw` baseline (`{Gettext.Macros, :*, :raw}` — every
  argument of every macro left untouched, the safe default) plus a per-position override for each
  arity with a `count` or `bindings` argument, routing just those trailing positions `:expression`
  (a more specific route takes precedence; see `Mutare.CallRouting`). For example `ngettext/4`
  routes `[:raw, :raw, :expression, :expression]` — the two message ids remain unchanged, while
  the count and bindings are mutated. The overrides are *derived* from the Gettext macro families;
  the test suite cross-checks every one against the `Gettext.Macros` exports.

  Targets Gettext **>= 0.26**, which introduced `Gettext.Macros`. On older versions, the injected
  `import Gettext.Macros` refers to a module that isn't loaded. Mutare leaves unresolved calls
  unchanged, so the extension has no effect.
  """

  @behaviour Mutare.UseExpansion
  @behaviour Mutare.CallRouting

  # The Gettext.Macros families: `{base_name, leading_literals, plural?}`.
  #   * `leading_literals` — the compile-time-literal args *before* the msgid: the domain (`d…`)
  #     and/or msgctxt (`p…`). Like the msgid(s) they must never be mutated (`:raw`).
  #   * `plural?` — the `ngettext` family, which carries a runtime `count` argument.
  # Each family also has a `…_with_backend` form (a leading `backend` module arg) and a `…_noop`
  # form (no runtime args). The `…_noop`s, `gettext_comment`, and the bare (no-`bindings`)
  # non-plural arities have nothing to mutate, so they fall to the whole-module `:raw` baseline;
  # only the arities `runtime_arg_overrides/0` generates carry a runtime `count` and/or `bindings`.
  @families [
    {:gettext, 0, false},
    {:dgettext, 1, false},
    {:pgettext, 1, false},
    {:dpgettext, 2, false},
    {:ngettext, 0, true},
    {:dngettext, 1, true},
    {:pngettext, 1, true},
    {:dpngettext, 2, true}
  ]

  @impl Mutare.UseExpansion
  def expand_use(Gettext, _args, _context),
    do: Mutare.UseExpansion.expand([quote(do: import(Gettext.Macros))])

  def expand_use(_used_module, _args, _context), do: :decline

  @impl Mutare.CallRouting
  def call_routes, do: [{Gettext.Macros, :*, :raw} | runtime_arg_overrides()]

  # Per-position overrides for the arities that carry a runtime `count` and/or `bindings` — the
  # trailing positions routed `:expression` on top of the whole-module `:raw` baseline. Everything
  # ahead of them (backend, domain, msgctxt, msgid(s)) stays `:raw`. Each family contributes a base
  # form and a `…_with_backend` form (one extra leading skip).
  defp runtime_arg_overrides do
    for {base, leading, plural?} <- @families,
        {name, backend?} <- [{base, false}, {:"#{base}_with_backend", true}],
        entry <- family_overrides(name, leading, plural?, backend?) do
      entry
    end
  end

  defp family_overrides(name, leading, plural?, backend?) do
    raws = leading_raws(leading, plural?, backend?)
    lead = length(raws)

    if plural? do
      # `count` is present in every ngettext arity; `bindings` only in the higher one.
      [
        entry(name, lead + 1, raws ++ [:expression]),
        entry(name, lead + 2, raws ++ [:expression, :expression])
      ]
    else
      # Only the `+ bindings` arity has a runtime arg; the bare arity is all-skip (wildcard covers it).
      [entry(name, lead + 1, raws ++ [:expression])]
    end
  end

  # The leading `:raw`s: backend (if any) + domain/msgctxt + msgid (+ msgid_plural for the plural
  # family). Everything up to, but not including, the runtime `count`/`bindings`.
  defp leading_raws(leading, plural?, backend?) do
    List.duplicate(:raw, bool(backend?) + leading + 1 + bool(plural?))
  end

  defp entry(name, arity, positions), do: {Gettext.Macros, name, arity, positions}

  defp bool(true), do: 1
  defp bool(false), do: 0
end
