defmodule Pop3mail.Base64Decoder do

   @moduledoc """
   Replaceable base64 decoder. Replace with your own implementation via the application config :pop3mail, base64_decoder: &lt;replacement&gt;

   After changing the config/config.exs run:
   * mix deps.compile pop3mail
   """

   @base64_decoder Application.get_env(:pop3mail, :base64_decoder) || Pop3mail.Base64Decoder.Standard

   defmodule Standard do

     @moduledoc "Standard Elixir base64 decoder"

     @doc "Decode base64 encoded text. Returns binary."
     def decode_lines!(lines) do
        encoded_text = Enum.join(lines)
        Base.decode64!(encoded_text)
     end

   end

   @doc "Decode base64 encoded text. Returns binary."
   defdelegate decode_lines!(lines), to: @base64_decoder

end
