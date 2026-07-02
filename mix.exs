defmodule Mutare.Gettext.MixProject do
  use Mix.Project

  def project do
    [
      app: :mutare_gettext,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Mutation-testing support for Gettext — a Mutare extension.",
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:mutare, path: "../mutare"},
      # Gettext is needed only to run *this package's own* tests: the end-to-end test resolves bare
      # `gettext`/`ngettext` calls through the injected `import Gettext.Macros`, which Mutare learns
      # by runtime reflection (`macro_exported?`), so `Gettext.Macros` must be loaded. A real
      # consumer already has gettext on its path; the extension only references the module *atoms*
      # (never calls them), so it neither compiles against nor ships gettext.
      {:gettext, "~> 0.26", only: :test},
      # Static-analysis tooling: lint (credo) and type/discrepancy checks (dialyxir). Dev/test
      # only, never shipped.
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # `mix check` is the single quality gate: formatting, lint, and type analysis. Any non-zero step
  # aborts the rest, so a green run means all three passed.
  defp aliases do
    [check: ["format --check-formatted", "credo", "dialyzer"]]
  end

  # PLTs land in priv/plts so they can be cached instead of rebuilt every run. :ex_unit/:mix aren't
  # in the dep tree but the lib and tests touch them, so they're added explicitly.
  defp dialyzer do
    [
      plt_local_path: "priv/plts",
      plt_core_path: "priv/plts",
      plt_add_apps: [:ex_unit, :mix]
    ]
  end
end
