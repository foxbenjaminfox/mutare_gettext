defmodule Mutare.Gettext do
  @moduledoc """
  A Mutare **extension** that teaches Mutare to read [Gettext](https://hexdocs.pm/gettext)'s
  translation macros, so the built-in mutators land on a `use Gettext` module without poisoning the
  single metamutant build.

  It is an **extension, not a mutator**: it produces no mutations, is charged no slot, and never
  appears in a report — it only makes the built-in mutators' work *land* (the bare `gettext` calls
  resolve; the right arguments are offered). List it under `:extensions` (in `.mutare.exs` or
  `Mutare.run/2`):

      # .mutare.exs
      [extensions: [Mutare.Gettext]]

  ## What it does

  Two capability behaviours, one per half of the Gettext problem (see `Mutare.Extension`):

    * **`c:Mutare.UseExpansion.expand_use/3`** — takes over every `use Gettext` line and injects the
      `import Gettext.Macros` directive it would. Gettext (>= 0.26) compiles
      `use Gettext, backend: MyApp.Gettext` by *mutating the caller module* to register the backend,
      which raises when Mutare expands it in the scan process (the caller is already compiled), so
      the `import` never surfaces and the bare `gettext`/`ngettext` calls never resolve. (The
      `backend:` value is a module alias, not a compile-time literal, so Mutare's static-literal
      opts gate would skip the expansion regardless.) Re-injecting the import directly is the fix —
      now the calls resolve and route.

    * **`c:Mutare.MacroRouting.macro_routes/0`** — routes each Gettext macro's arguments. The **compile-time
      literal** positions — message id, plural id, domain, context, backend — must never be mutated:
      they have to stay literals, and splicing a mutation selector there makes the macro raise while
      expanding and poisons the build. The **runtime** positions — the `ngettext` plural `count` and
      the interpolation `bindings` — *are* mutated, so a stale plural threshold or a wrong
      interpolation value still gets caught.

  This is expressed as a whole-module `:skip` baseline (`{Gettext.Macros, :*, :skip}` — every
  argument of every macro left untouched, the safe default) plus a per-position override for each
  arity that carries a `count`/`bindings`, routing just those trailing positions `:expression` (a
  more specific route wins; see `Mutare.MacroRouting`). For example `ngettext/4` routes
  `[:skip, :skip, :expression, :expression]` — the two msgids stay literal, the count and bindings
  mutate. The overrides are *derived* from the Gettext macro families rather than hand-listed, so a
  position can't drift (the package's test cross-checks every one against the real `Gettext.Macros`).

  Targets Gettext **>= 0.26** (the `Gettext.Macros` era). On an older Gettext the injected
  `import Gettext.Macros` names a module that isn't loaded, so resolution conservatively skips it and
  the extension degrades to a harmless no-op.
  """

  @behaviour Mutare.UseExpansion
  @behaviour Mutare.MacroRouting

  # The Gettext.Macros families: `{base_name, leading_literals, plural?}`.
  #   * `leading_literals` — the compile-time-literal args *before* the msgid: the domain (`d…`)
  #     and/or msgctxt (`p…`). Like the msgid(s) they must never be mutated (`:skip`).
  #   * `plural?` — the `ngettext` family, which carries a runtime `count` argument.
  # Each family also has a `…_with_backend` form (a leading `backend` module arg) and a `…_noop`
  # form (no runtime args). The `…_noop`s, `gettext_comment`, and the bare (no-`bindings`)
  # non-plural arities have nothing to mutate, so they fall to the whole-module `:skip` baseline;
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

  @impl Mutare.MacroRouting
  def macro_routes, do: [{Gettext.Macros, :*, :skip} | runtime_arg_overrides()]

  # Per-position overrides for the arities that carry a runtime `count` and/or `bindings` — the
  # trailing positions routed `:expression` on top of the whole-module `:skip` baseline. Everything
  # ahead of them (backend, domain, msgctxt, msgid(s)) stays `:skip`. Each family contributes a base
  # form and a `…_with_backend` form (one extra leading skip).
  defp runtime_arg_overrides do
    for {base, leading, plural?} <- @families,
        {name, backend?} <- [{base, false}, {:"#{base}_with_backend", true}],
        entry <- family_overrides(name, leading, plural?, backend?) do
      entry
    end
  end

  defp family_overrides(name, leading, plural?, backend?) do
    skips = leading_skips(leading, plural?, backend?)
    lead = length(skips)

    if plural? do
      # `count` is present in every ngettext arity; `bindings` only in the higher one.
      [
        entry(name, lead + 1, skips ++ [:expression]),
        entry(name, lead + 2, skips ++ [:expression, :expression])
      ]
    else
      # Only the `+ bindings` arity has a runtime arg; the bare arity is all-skip (wildcard covers it).
      [entry(name, lead + 1, skips ++ [:expression])]
    end
  end

  # The leading `:skip`s: backend (if any) + domain/msgctxt + msgid (+ msgid_plural for the plural
  # family). Everything up to, but not including, the runtime `count`/`bindings`.
  defp leading_skips(leading, plural?, backend?) do
    List.duplicate(:skip, bool(backend?) + leading + 1 + bool(plural?))
  end

  defp entry(name, arity, positions), do: {Gettext.Macros, name, arity, positions}

  defp bool(true), do: 1
  defp bool(false), do: 0
end
