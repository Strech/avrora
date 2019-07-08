%{
  configs: [
    %{
      name: "default",
      color: true,
      strict: true,
      files: %{
        included: ["lib/", "test/"],
        excluded: [~r"/_build/", ~r"/deps/"]
      },
      checks: [
        {Credo.Check.Readability.MaxLineLength, max_length: 120},
        {Credo.Check.Readability.LargeNumbers, only_greater_than: 99_999}
      ]
    }
  ]
}
