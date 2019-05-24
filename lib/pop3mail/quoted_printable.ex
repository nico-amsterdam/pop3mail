defmodule Pop3mail.QuotedPrintable do

   @moduledoc "Decode quoted-printable text as in RFC 2045 # 6.7"

   @doc "Decode `arg1` string. Returns the result as a character list."
   @spec decode(String.t) :: list(char)
   def decode(str), do: do_decode(str, [])

   defp do_decode("", acc), do: :lists.reverse(acc)

   # remove trailing \r\n
   defp do_decode(<< 13 :: size(8), 10 :: size(8) >>, acc), do: :lists.reverse(acc)

   # strip off =\r\n
   defp do_decode(<< "=", 13 :: size(8), 10 :: size(8), data :: binary >>, acc), do: do_decode(data, acc)

   # convert = hex values to characters
   defp do_decode(<< "=", hex1 :: size(8), hex2 :: size(8), data :: binary >>, acc) do
       hex_value = to_string [hex1, hex2]
       case Integer.parse(hex_value, 16) do
         {char_as_int, ""} -> do_decode(data, [char_as_int | acc])
         :error            -> do_decode(data, [hex2, hex1, ?= | acc])
         {_, _}            -> do_decode(data, [hex2, hex1, ?= | acc])  # wrongly encoded
       end
   end

   # normal characters
   defp do_decode(<<char_as_int :: size(8), data :: binary >>, acc) do
      do_decode(data, [char_as_int | acc])
   end

end
