# Functions to decode:
# RFC2047 encoded-words
# 
# 
defmodule Pop3mail.WordDecoder do
  alias Pop3mail.QuotedPrintable

   def decode_text(input_text) do
     decoded_text_list = [{"us-ascii", input_text}]
     if String.contains?(input_text, "?=") do
        # RFC 2045
        # When displaying a particular header field that contains multiple
        # 'encoded-word's, any 'linear-white-space' that separates a pair of
        # adjacent 'encoded-word's is ignored.  (This is to allow the use of
        # multiple 'encoded-word's to represent long strings of unencoded text,
        # without having to separate 'encoded-word's where spaces occur in the
        # unencoded text.)

        # remove with space between encoded words (?= is forward lookahead, so the search pattern can be applied multiple times) 
        # \\1 is group1, \\2 is group2 and \s+ is removed
        input_text = Regex.replace(~r/(=\?[\w-]+\?[BQbq]\?[^\s]*\?=)\s+(?==\?[\w-]+\?[BQbq]\?[^\s]*\?=)/U, input_text, "\\1\\2")

        # make a list with us-ascii text and encoded-word's separated
        text_list = Regex.split(~r/()=\?[\w-]+\?[BQbq]\?[^\s]*\?=()/U, input_text, on: [1,2])
        
        decoded_text_list = Enum.map(text_list, &decode_word(&1))
     end
     decoded_text_list
   end

   # return a list with text and the text encoding
   # RFC822
   def decode_word(text) do
     if String.starts_with?(text, "=?") do

        found_word = Regex.run(~r/=\?([\w-]+)\?([BQbq])\?([^\s]*)\?=/, text)

        if found_word == nil do
           {"us-ascii", text}
        else
           [_, charset, encoding, encoded_text] = found_word
           decoded_text = decode_word(encoded_text, encoding)
           {charset, decoded_text}
        end
     else
       {"us-ascii", text}
     end
   end

   def decode_word(text, encoding) when encoding in ["B", "b"] do
      to_char_list(text) |> :base64.decode
   end

   def decode_word(text, encoding) when encoding in ["Q", "q"] do
      # RFC2047: The 8-bit hexadecimal value 20 (e.g., ISO-8859-1 SPACE) may be represented as "_" (underscore, ASCII 95.).
      String.replace(text, "_", " ") |> QuotedPrintable.decode |> :erlang.list_to_binary
   end

   # returns sorted unique list. Because the non-encoded text has the us-ascii charset (a subset of utf-8 iso-8859-1 cp1251) we are particulary interested in the other charsets.
   def get_charsets_besides_ascii(decoded_text_list) do
     Enum.map(decoded_text_list, fn({charset, _}) -> charset end) |> Enum.filter( fn(charset) -> charset != "us-ascii" end ) |> Enum.sort |> Enum.dedup
   end

   # copies text as it is. Does NOT convert to a common character set like utf-8.
   def decoded_text_list_to_string(decoded_text, add_charset_name) do
      Enum.map(decoded_text, fn({charset, text}) -> if add_charset_name and charset != "us-ascii" and String.length(text) > 0, do: text = "#{text} (#{charset})"; text; end) |> Enum.join
   end

end
