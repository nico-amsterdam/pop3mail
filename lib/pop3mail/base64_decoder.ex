defmodule Pop3mail.Base64Decoder do

   @moduledoc "Replaceable base64 decoder. Replace with your own implementation via the application config :pop3mail, base64_decoder: <replacement>."

   use Logger
   
   defmodule Standard do

     @moduledoc "Standard Erlang base64 decoder"

     @doc "Decode base64 encoded text. Returns binary."
     def decode!(encoded_text) do
        Base.decode64!(encoded_text, ignore: :whitespace)
     end

   end

   def get_decoder do
      Logger.debug Application.get_env(:pop3mail, :base64_decoder)
      Application.get_env(:pop3mail, :base64_decoder) || Pop3mail.Base64Decoder.Standard
   end

   @doc "Decode base64 encoded text. Returns binary."
   defdelegate decode!(encoded_text), to: get_decoder()

end
