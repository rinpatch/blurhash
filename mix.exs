defmodule Blurhash.MixProject do
  use Mix.Project

  def project do
    [
      app: :blurhash,
      version: "0.1.0",
      elixir: "~> 1.10",
      package: package(),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def package do
    [
      maintainers: ["rinpatch"],
      licenses: ["MIT"],
      description: "A pure Elixir blurhash decoder/encoder.",
      links: %{
        "Github" => "https://github.com/rinpatch/blurhash",
        "Issues" => "https://github.com/rinpatch/blurhash/issues",
      },
      name: :rinpatch_blurhash
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mogrify, "~> 0.8.0", optional: true},
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end
end
