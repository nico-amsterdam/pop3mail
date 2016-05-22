defmodule Pop3mail.Mixfile do
  use Mix.Project

  def project do
    [app: :pop3mail,
     version: "0.1.0",
     elixir: "~> 1.2",
     description: description,
     package: package,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
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
    [{:erlpop, github: "trifork/erlpop"}]
  end

  defp description do
    """
    Pop3 client to download email (including attachments) from the inbox via the commandline or Elixir API.
    Written in Elixir, using an Erlang pop3 client with SSL support derived from the epop package.
    Decodes multipart content, quoted-printables, base64 and encoded-words.
    """
  end

  defp package do
    [# These are the default files included in the package
     name: :pop3mail,
     maintainers: ["Nico Hoogervorst"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/nico-amsterdam/pop3mail"}]
  end
end
