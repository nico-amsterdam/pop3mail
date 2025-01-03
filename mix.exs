defmodule Pop3mail.Mixfile do
  use Mix.Project

  @version "1.5.1"
  @source_url "https://github.com/nico-amsterdam/pop3mail"

  def project do
    [
      app: :pop3mail,
      version: @version,
      elixir: "~> 1.14",

      # Hex
      package: package(),
      description: description(),

      # Docs
      docs: [
        source_ref: "master",
        main: "Pop3mail",
        canonical: "http://hexdocs.pm/pop3mail",
        source_url: @source_url
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_apps: [:mix]]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
     extra_applications: [:logger, :inets, :ssl]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:pop3client, "~> 1.4.0"},
      {:ex_doc, "~> 0.36"  , only: :dev, runtime: false},
      {:credo,  "~> 1.7"   , only: :dev, runtime: false},
      {:dialyxir, "~> 1.4" , only: :dev, runtime: false}
    ]
  end

  defp description do
    """
    Pop3 client to download email (including attachments) from the inbox.
    Decodes multipart content, quoted-printables, base64 and encoded-words.
    Uses an Erlang pop3 client with SSL support derived from the epop package.
    """
  end

  defp package do
    [
      name: :pop3mail,
      maintainers: ["Nico Hoogervorst"],
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end
end
