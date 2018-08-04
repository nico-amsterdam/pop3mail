defmodule Pop3mail.QuotedPrintable do

   @moduledoc "Decode quoted-printable text as in RFC 2045 # 6.7"

   @doc "Decode `arg1` string. Returns the result as a character list."
   @spec decode(String.t) :: list(char)
   def decode(""), do: []

   # remove trailing \r\n
   def decode(<< 13 :: size(8), 10 :: size(8) >>), do: []

   # strip off =\r\n
   def decode(<< "=", 13 :: size(8), 10 :: size(8), data :: binary >>), do: decode(data)

   # convert = hex values to characters
   def decode(<< "=", hex1 :: size(8), hex2 :: size(8), data :: binary >>) do
       hex_value = to_string [hex1, hex2]
       case Integer.parse(hex_value, 16) do
         :error -> '=' ++ [hex1, hex2] ++ decode(data)
         {char_as_int, ""} -> [char_as_int] ++ decode(data)
         {_, _} -> '=' ++ [hex1, hex2] ++ decode(data)  # wrongly encoded
       end
   end

   # normal characters
   def decode(<<char_as_int :: size(8), data :: binary >>) do
     [char_as_int] ++ decode(data)
   end

end
