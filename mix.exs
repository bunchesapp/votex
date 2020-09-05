defmodule Votex.MixProject do
  use Mix.Project

  def project do
    [
      app: :votex,
      version: "0.4.0",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ecto]
    ]
  end

  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, "~> 3.4.4"},
      {:ecto_sql, "~> 3.4.5"}
    ]
  end
end
