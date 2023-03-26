defmodule Gundam.MixProject do
  use Mix.Project

  def project do
    [
      app: :gundam,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env),
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end
  
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gun, "~> 2.0"},
      {:cowlib, "~> 2.12.0", override: true},
      {:plug, "~> 1.14"},
      {:plug_cowboy, "~> 2.0", only: [:test]}
    ]
  end
end
