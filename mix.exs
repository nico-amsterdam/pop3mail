defmodule Pop3mail.Mixfile do
  use Mix.Project

  def project do
    [app: :pop3mail,
     version: "0.1.7",
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
    [ {:erlpop, github: "trifork/erlpop"},
      # {:earmark,  "~> 0.1", only: :dev},
      {:ex_doc,  "~> 0.12", only: :dev},
      {:credo,  "~> 0.4"  , only: :dev}
    ]
  end

  defp description do
    """
    Pop3 client to download email (including attachments) from the inbox.
    Decodes multipart content, quoted-printables, base64 and encoded-words.
    Uses an Erlang pop3 client with SSL support derived from the epop package. Add this dependency in mix.exs: 
    {:erlpop, github: "trifork/erlpop"}
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
