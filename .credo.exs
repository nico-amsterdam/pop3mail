# .credo.exs
%{
  configs: [
    %{
      name: "default",
      strict: true,
      checks: %{
        disabled: [
          {Credo.Check.Readability.PredicateFunctionNames, []}
        ],
        enabled: [
          {Credo.Check.Readability.MaxLineLength, max_length: 170}
        ]
      }
      # files etc.
    }
  ]
}
