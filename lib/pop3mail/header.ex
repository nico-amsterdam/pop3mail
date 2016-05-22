defmodule Pop3mail.Header do
  alias Pop3mail.WordDecoder
  alias Pop3mail.FileStore

   def lookup(header_list, header_name) do
     # filter list on name, return comma separated
     header_name = to_char_list(header_name)
     Enum.filter_map(header_list, fn({:header, name, _}) -> name == header_name end, fn({:header, _, val}) -> val end) |>  Enum.join(", ")
   end

   def store(header_list, filename_prefix, dirname) do
      date    = lookup(header_list, "Date")
      # RFC2047, search for encoded words and put these in decoded text list, like  [{charset1,content1},{charset2,content2}]
      from_decoded    = lookup(header_list, "From")    |> WordDecoder.decode_text
      subject_decoded = lookup(header_list, "Subject") |> WordDecoder.decode_text
      to_decoded      = lookup(header_list, "To")      |> WordDecoder.decode_text
      cc_decoded      = lookup(header_list, "Cc")      |> WordDecoder.decode_text
      charsets = WordDecoder.get_charsets_besides_ascii(subject_decoded ++ from_decoded ++ to_decoded ++ cc_decoded)
      # mention the charsets used in the filename:
      if length(charsets) > 0 do
         filename_prefix = filename_prefix <> "." <> Enum.join(charsets, "_") 
      end
      # mention the charset in the file content if multiple charsets are used:
      mention_charset = length(charsets) > 1
      create_content_and_store(from_decoded, to_decoded, cc_decoded, subject_decoded, mention_charset, date, filename_prefix <> ".txt", dirname)
   end

   defp create_content_and_store(from_decoded, to_decoded, cc_decoded, subject_decoded, mention_charset, date, filename, dirname) do
      # create file content
      line_sep = :io_lib.nl() |> to_string
      content = "Date: " <> date <> line_sep <> 
                "From: " <> WordDecoder.decoded_text_list_to_string(from_decoded, mention_charset) <> line_sep <> 
                "To: " <> WordDecoder.decoded_text_list_to_string(to_decoded, mention_charset) 

      # optional content
      cc = WordDecoder.decoded_text_list_to_string(cc_decoded, mention_charset)
      if String.length(cc) > 0, do: content = content <> line_sep <> "Cc: " <> cc

      subject = WordDecoder.decoded_text_list_to_string(subject_decoded, mention_charset)
      if String.length(subject) > 0, do: content = content <> line_sep <> "Subject: " <> subject
     
      # store
      FileStore.store_mail_header(content, filename, dirname)
   end
end
