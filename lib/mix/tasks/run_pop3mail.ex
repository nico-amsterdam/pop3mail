defmodule Mix.Tasks.RunPop3mail do
  use Mix.Task

  @shortdoc "Retrieve email from a POP3 mailbox"

  @moduledoc """
  Retrieve email from a POP3 mailbox.
  
  Examples:
    * mix run_pop3mail --username=h.lorentz@gmail.com --max 100 --raw
    * mix run_pop3mail --help
  """
  def run(args) do
    Pop3mail.cli(args)
  end
end

