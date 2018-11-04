defmodule Pop3mail.Header do
  alias Pop3mail.WordDecoder
  alias Pop3mail.FileStore

   @moduledoc "Email header related functions."

   @doc """
   Lookup value by header name. Returns a string.

   If the searched header name occurs multiple times in the list, the result will be the concatenated comma separated value.

   `header_list` - list with tuples {:header, header name, value}
   """
   @spec lookup(list({:header, String.t, String.t}), String.t) :: String.t
   def lookup(header_list, header_name) do
     lc_header_name = String.downcase(header_name)
     header_list
     |> Enum.filter(fn({:header, name, _}) -> String.downcase(name) == lc_header_name end)
     |>    Enum.map(fn({:header, _,  val}) -> val end)
     |> Enum.join(", ")
   end

   @doc """
   Store email headers Date,From,To,Cc and Subject in a text file.

   filename is `filename_prefix` . `unsafe_addition` . txt

   * `header_list` - list with tuples {:header, header name, value}
   * `unsafe_addition` - append this to the filename if the filesystem allows it.
   """
   @spec store(list({:header, String.t, String.t}), String.t, String.t, String.t) :: {:ok, String.t} | {:error, String.t, String.t}
   def store(header_list, filename_prefix, filename_addition, dirname) do
      date    = lookup(header_list, "Date")
      # RFC 2047, search for encoded words and put these in decoded text list, like  [{charset1,content1},{charset2,content2}]
      from_decoded    = header_list |> lookup("From")    |> WordDecoder.decode_text
      subject_decoded = header_list |> lookup("Subject") |> WordDecoder.decode_text
      to_decoded      = header_list |> lookup("To")      |> WordDecoder.decode_text
      cc_decoded      = header_list |> lookup("Cc")      |> WordDecoder.decode_text
      charsets = WordDecoder.get_charsets_besides_ascii(subject_decoded ++ from_decoded ++ to_decoded ++ cc_decoded)
      # mention the charsets used in the filename:
      filename_prefix =
        case length(charsets) > 0 do
           true  -> filename_prefix <> "." <> Enum.join(charsets, "_")
           false -> filename_prefix
        end

      # mention the charset in the file content if multiple charsets are used:
      mention_charset = length(charsets) > 1
      # create file content
      line_sep = FileStore.get_line_separator()
      content = "Date: " <> date <> line_sep <>
                "From: " <> WordDecoder.decoded_text_list_to_string(from_decoded, mention_charset) <> line_sep <>
                "To: " <> WordDecoder.decoded_text_list_to_string(to_decoded, mention_charset)

      # optional content
      cc = WordDecoder.decoded_text_list_to_string(cc_decoded, mention_charset)
      content =
        case String.length(cc) > 0 do
           true  -> content <> line_sep <> "Cc: " <> cc
           false -> content
        end

      # optional content
      subject = WordDecoder.decoded_text_list_to_string(subject_decoded, mention_charset)
      content =
        case String.length(subject) > 0 do
           true  -> content <> line_sep <> "Subject: " <> subject
           false -> content
        end

      # store
      FileStore.store_mail_header(content, filename_prefix, filename_addition, dirname)
   end
end
