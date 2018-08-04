# Functions to decode:
# RFC 2047 encoded-words
#
#
defmodule Pop3mail.WordDecoder do
  alias Pop3mail.QuotedPrintable
  alias Pop3mail.Base64Decoder

   @moduledoc "Decode words as defined in RFC 2047."

   @doc "Decode a text with possibly encoded-words. Returns a list with tuples {charset, text}. Not encoded text is returned with us-ascii charset."
   @spec decode_text(String.t) :: list({String.t, binary})
   def decode_text(input_text) do
     if String.contains?(input_text, "=?") do
        # RFC 2045:
        # When displaying a particular header field that contains multiple
        # 'encoded-word's, any 'linear-white-space' that separates a pair of
        # adjacent 'encoded-word's is ignored.  (This is to allow the use of
        # multiple 'encoded-word's to represent long strings of unencoded text,
        # without having to separate 'encoded-word's where spaces occur in the
        # unencoded text.)

        # remove white space between encoded words (?= is forward lookahead, so the search pattern can be applied multiple times)
        # \\1 is group1, \\2 is group2 and \s+ is not in the replacement.
        input_text = Regex.replace(~r/(=\?[\w-]+\?[BQbq]\?[^\s]*\?=)\s+(?==\?[\w-]+\?[BQbq]\?[^\s]*\?=)/U, input_text, "\\1\\2")

        # make a list with us-ascii text and encoded-word's separated
        text_list = Regex.split(~r/()=\?[\w-]+\?[BQbq]\?[^\s]*\?=()/U, input_text, on: [1, 2])

        text_list
        |> Enum.filter(fn(x) -> x != "" end)
        |> Enum.map(&decode_word(&1))
     else
        [{"us-ascii", input_text}]
     end
   end

   @doc "Decode a word. text with possibly encoded-words. Returns a list with tuples {charset, text}. Not encoded text is returned with us-ascii charset."
   @spec decode_word(String.t) :: {String.t, binary}
   def decode_word(text) do
     if String.starts_with?(text, "=?") do

        found_word = Regex.run(~r/=\?([\w-]+)\?([BQbq])\?([^\s]*)\?=/, text)

        case found_word do
           nil -> {"us-ascii", text}
           _ ->
              [_, charset, encoding, encoded_text] = found_word
              decoded_text = decode_word(encoded_text, encoding)
              {charset, decoded_text}
        end
     else
       {"us-ascii", text}
     end
   end

   @doc """
   Decode a word with the given encoding.

   `encoding` - B/Q B=base64 encoded, Q=Quoted-printable
   """
   @spec decode_word(String.t, <<_::8>>) :: binary
   def decode_word(text, encoding) when encoding in ["B", "b"] do
      try do
         Base64Decoder.decode!(text)
      rescue
         _ -> text
      end
   end

   def decode_word(text, encoding) when encoding in ["Q", "q"] do
      # RFC 2047: The 8-bit hexadecimal value 20 (e.g., ISO-8859-1 SPACE) may be represented as "_" (underscore, ASCII 95.).
      text
      |> String.replace("_", " ")
      |> QuotedPrintable.decode
      |> :erlang.list_to_binary
   end

   @doc """
   returns sorted unique list of charsets.

   Because the non-encoded text has the us-ascii charset (a subset of utf-8 iso-8859-1 cp1251) we are particulary interested in the other charsets.

   `decoded_text_list` - list with tuples {charset, text}.
   """
   @spec get_charsets_besides_ascii(list({String.t, String.t})) :: list({String.t}) 
   def get_charsets_besides_ascii(decoded_text_list) do
     decoded_text_list
     |> Enum.map(fn({charset, _}) -> charset end)
     |> Enum.filter(fn(charset) -> charset != "us-ascii" end)
     |> Enum.sort
     |> Enum.dedup
   end

   @doc """
   Concat the text from the decoded list. Does NOT convert to a common character set like utf-8.

   * `decoded_text_list` - list with tuples {charset, text}.
   * `add_charset_name` - put the name of the charset after the decoded text parts (when it isn't us-ascii). A hint for the reader if a text contains multiple charsets.
   """
   @spec decoded_text_list_to_string(list({String.t, String.t}), boolean) :: String.t
   def decoded_text_list_to_string(decoded_text_list, add_charset_name \\ false) do
      map_text_fun = if add_charset_name, do: &with_charset/1, else: &without_charset/1
      decoded_text_list
      |> Enum.map(map_text_fun)
      |> Enum.join
   end

   # return just the text
   defp without_charset({_charset, text}), do: text

   # return text with name of charset if it isn't just ascii
   defp with_charset({charset, text}) do
      case charset != "us-ascii" and String.length(text) > 0 do
         true -> "#{text} (#{charset})"
         _    -> text
      end
   end

end
