#  RFC 2045 # 6.7 Quoted-Printable Content-Transfer-Encoding
defmodule Pop3mail.QuotedPrintable do
   
   def decode(""), do: [] 
   
   # remove trailing \r\n
   def decode(<< 13 :: size(8), 10 :: size(8) >>), do: []

   # strip off =\r\n
   def decode(<< "=", 13 :: size(8), 10 :: size(8), data :: binary >>), do: decode(data)

   # convert = hex values to characters
   def decode(<< "=", header1 :: size(8), header2 :: size(8), data :: binary >>) do
       hex_value = to_string [header1, header2] 
       case Integer.parse(hex_value, 16) do
         :error -> '=' ++ [header1, header2] ++ decode(data) 
         {char_as_int, ""} -> [char_as_int] ++ decode(data)
       end
   end

   # normal characters
   def decode(<<char_as_int :: size(8), data :: binary >>) do
     [char_as_int] ++ decode(data)
   end

end
