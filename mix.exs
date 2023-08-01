defmodule Shogun.MixProject do
  use Mix.Project

  def project do
    [
      app: :shogun,
      version: "0.1.5",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      package: package(),
      aliases: aliases()
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

  defp package do
    %{
      name: "shogun",
      licenses: ["GPLv3"],
      authors: ["Erik Gonzalez"],
      description: "Websocket client",
      links: %{"Github" => "https://github.com/erikhu/shogun"}
    }
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gun, "~> 2.0"},
      {:plug, "~> 1.14", only: [:test]},
      {:plug_cowboy, "~> 2.6", only: [:test]},
      {:x509, "~> 0.8.5", only: :test},
      {:tls_certificate_check, "~> 1.18"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["x509.gen.suite -f -p shogun -o test/fixtures/ssl", "test"]
    ]
  end
end
