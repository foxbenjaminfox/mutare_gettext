defmodule Mutare.Gettext.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/foxbenjaminfox/mutare_gettext"

  def project do
    [
      app: :mutare_gettext,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      description: "Mutation-testing support for Gettext — a Mutare extension.",
      package: package(),
      lockfile: System.get_env("MIX_LOCKFILE", "mix.lock"),
      deps: deps(),
      aliases: aliases(),
      dialyzer: dialyzer(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp package do
    [
      maintainers: ["Benjamin Fox"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Mutare" => "https://hexdocs.pm/mutare",
        "Changelog" => "https://hexdocs.pm/mutare_gettext/changelog.html"
      },
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end

  defp deps do
    [
      {:mutare, "~> 0.1", path: "../mutare"},
      # Gettext is needed only to run *this package's own* tests: the end-to-end test resolves bare
      # `gettext`/`ngettext` calls through the injected `import Gettext.Macros`, which Mutare learns
      # by runtime reflection (`macro_exported?`), so `Gettext.Macros` must be loaded. A real
      # consumer already has gettext on its path; the extension only references the module *atoms*
      # (never calls them), so it neither compiles against nor ships gettext.
      # The requirement is env-overridable so CI can pin the declared minimum
      # (see ci.yml); local runs fall back to the locked (latest) Gettext.
      {:gettext, System.get_env("GETTEXT_REQUIREMENT", "~> 0.26"), only: :test},
      # Static-analysis tooling: lint (credo) and type/discrepancy checks (dialyxir). Dev/test
      # only, never shipped.
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
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
      plt_add_apps: [:ex_unit, :mix],
      # Same high-signal spec-accuracy checks mutare itself runs with.
      flags: [:error_handling, :extra_return, :missing_return]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", "LICENSE"]
    ]
  end
end
