defmodule Mutare.GettextTest do
  use ExUnit.Case, async: true

  alias Mutare.Gettext, as: Extension
  alias Mutare.UseExpansion.Expansion

  describe "expand_use/3" do
    test "takes over `use Gettext` by injecting `import Gettext.Macros`" do
      assert %Expansion{directives: [directive], behaviours: []} =
               Extension.expand_use(Gettext, [[backend: MyApp.Gettext]], %{
                 module: MyApp.Web,
                 opts: []
               })

      assert Macro.to_string(directive) == "import Gettext.Macros"
    end

    test "declines any other `use`" do
      assert Extension.expand_use(Phoenix, [], %{module: MyApp.Web, opts: []}) == :decline
      assert Extension.expand_use(GenServer, [], %{module: MyApp.Server, opts: []}) == :decline
    end
  end

  describe "macro_routes/0" do
    test "skips everything by default, then mutates the runtime count/bindings positions" do
      entries = Extension.macro_routes()

      # The whole-module :skip baseline keeps every msgid/domain/context/backend a literal.
      assert {Gettext.Macros, :*, :skip} in entries

      # Per-position overrides route the runtime count/bindings :expression while the leading
      # literal positions stay :skip — spot-checks across the singular, plural, and backend forms.
      assert {Gettext.Macros, :gettext, 2, [:skip, :expression]} in entries
      assert {Gettext.Macros, :ngettext, 3, [:skip, :skip, :expression]} in entries
      assert {Gettext.Macros, :ngettext, 4, [:skip, :skip, :expression, :expression]} in entries
      assert {Gettext.Macros, :dgettext, 3, [:skip, :skip, :expression]} in entries

      assert {Gettext.Macros, :dpngettext_with_backend, 7,
              [:skip, :skip, :skip, :skip, :skip, :expression, :expression]} in entries
    end

    test "every override names a real Gettext.Macros macro and never mutates a literal position" do
      exported = MapSet.new(Gettext.Macros.__info__(:macros))

      overrides =
        Enum.filter(
          Extension.macro_routes(),
          &match?({Gettext.Macros, _, arity, _} when is_integer(arity), &1)
        )

      # There are runtime-arg macros across all eight families (singular + plural, each with a
      # _with_backend form), so the override set is non-trivial.
      assert length(overrides) >= 20

      for {Gettext.Macros, name, arity, positions} = entry <- overrides do
        # Names a macro that actually exists at that arity (no inert/typo'd entries).
        assert {name, arity} in exported,
               "#{name}/#{arity} is not a Gettext.Macros macro (#{inspect(entry)})"

        # The position list matches the arity, every :expression sits at the *trailing* (runtime)
        # positions — never on a leading literal (backend/domain/msgctxt/msgid), which would poison
        # — and at least one runtime position is actually mutated.
        n_expr = Enum.count(positions, &(&1 == :expression))
        assert n_expr in 1..2
        assert length(positions) == arity

        assert positions ==
                 List.duplicate(:skip, arity - n_expr) ++ List.duplicate(:expression, n_expr),
               "#{name}/#{arity} mutates a non-trailing position: #{inspect(positions)}"
      end
    end
  end

  test "validates as a Mutare extension (not a mutator)" do
    assert Mutare.Extension.extension?(Extension)
  end

  describe "end to end through Mutare.transform_string" do
    @source """
    defmodule MyApp.Greeter do
      use Gettext, backend: MyApp.Gettext

      def hello(count) do
        greeting = gettext("Hello %{who}", who: count + 1)
        plural = ngettext("one apple", "many apples", count + 2)
        {greeting, plural}
      end
    end
    """

    @mutators [Mutare.Mutators.StringLiteral, Mutare.Mutators.Arithmetic]

    test "skips the msgids but mutates the runtime count and bindings" do
      {_with_src, with_sites, _} =
        Mutare.transform_string(@source, mutators: @mutators, extensions: [Extension])

      {_without_src, without_sites, _} =
        Mutare.transform_string(@source, mutators: @mutators)

      # Without the extension the bare gettext/ngettext calls don't resolve, so the msgids are
      # mutated as ordinary runtime strings — the path that would poison the single build.
      assert count(without_sites, :string) > 0

      # With the extension the `import Gettext.Macros` surfaces, the calls resolve, and the msgids
      # (singular, plural — all compile-time literals) are routed :skip: not one StringLiteral site.
      assert count(with_sites, :string) == 0

      # But the runtime positions ARE mutated even with the extension: the bindings value `count + 1`
      # and the ngettext count `count + 2` are both routed :expression, so Arithmetic still fires on
      # them — identically to the no-extension run (the extension removes *only* the literal
      # mutations).
      assert count(with_sites, :arithmetic) == count(without_sites, :arithmetic)
      assert count(with_sites, :arithmetic) > 0
    end
  end

  defp count(sites, mutator), do: Enum.count(sites, &(&1.mutator == mutator))
end
