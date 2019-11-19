defmodule UnicodeSet.MixProject do
  use Mix.Project

  def project do
    [
      app: :unicode_set,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_unicode, path: "../unicode"},
      {:nimble_parsec, "~> 0.5", runtime: false}
    ]
  end
end
