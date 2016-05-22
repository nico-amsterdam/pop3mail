# Parser for: RFC2045 Multipart content type (previously RFC1341)
# It works recursive because a multipart content can contain other multiparts.
# The returned sequential list of Path structs is flattened. The Part.path shows where it is in the hierarchy.
# This could also be useful to parse RFC7578 multipart/form-data (previously RFC2388).
defmodule Pop3mail.Multipart do
  alias Pop3mail.Part
  alias Pop3mail.StringUtils
  alias Pop3mail.QuotedPrintable
  alias Pop3mail.WordDecoder

  require Logger

   # This is called for each multipart content
   # Returns flat list of Part's 
   def parse_content(multipart_part) do
      if is_multipart?(multipart_part) do
         extra_path  = multipart_part.media_type |> String.split("/") |> List.last
         new_path    = Path.join(multipart_part.path, extra_path)
         # Logger.info "    Process multipart: #{new_path}"
         top_level_multipart_part_list = parse_multipart(multipart_part.boundary, multipart_part.content, new_path)

         # multiparts can contain other multiparts, go deeper
         Enum.flat_map(top_level_multipart_part_list, &(parse_content(&1)))
      else
         # ready
         [multipart_part]
      end
   end
   
   def is_multipart?(multipart_part) do
      String.starts_with?(String.downcase(multipart_part.media_type), "multipart/")
   end

   def parse_multipart(boundary_name, raw_content, path) do
     # split at --boundary
     [_ | parts] = String.split(raw_content, "--" <> boundary_name)
     Enum.with_index(parts, 1) |> Enum.flat_map(&(parse_part(&1, path)))
   end


   def parse_part({part, index}, path) do
     # part = %{multipart_part | index: index}
     # bare carriage returns or bare linefeeds are not allowed in email.
     lines = String.split(part, ~r/\r\n/)
     line = List.first(lines)
     # Because we did split at --boundary, the end boundary '--boundary--' is split in '--boundary' and '--'. So '--' indicates that we are ready with the multipart.
     if String.starts_with?(line, "--") or length(lines) < 2 do
       # ready with the multipart
       []
     else
        # ignore first line because that's the text after the boundary and it should be empty
        [_| other_lines] = lines
        new_part = %Part{path: path, index: index}
        multipart_part = parse_part_lines(new_part, "raw", other_lines)
        # return list of parts
        [multipart_part] 
     end
   end

   # header lines are processed, now decode the content
   def parse_part_decode(multipart_part, encoding, lines) do
     content = decode_lines(encoding, lines)
     %{multipart_part | content: content}
   end

   def decode_lines(encoding, lines) do
     decode(encoding, Enum.join(lines, "\r\n"))
   end

   def parse_part_finish(multipart_part, encoding, [line | otherlines]) do
     # there should be an empty line after the headers
     if String.length(String.strip(line)) > 0 do
        # this is not always the case or we have an unknown header here.
        Logger.warn "Missing newline or unknown header in body at line: " <> line
        # fix; don't skip line
        otherlines = [line | otherlines]
     end
     parse_part_decode(multipart_part, encoding, otherlines)
   end

   # when all header lines are read and there are no more lines
   def parse_part_lines(multipart_part, encoding, []) do
       parse_part_decode(multipart_part, encoding, [])
   end

   def parse_part_lines(multipart_part, encoding, [line | otherlines]) do
       lc_line = String.downcase(line)
       all_lines = [line | otherlines]
       cond do
         String.starts_with?(lc_line, "content-type:")              -> parse_part_content_type(multipart_part, encoding, all_lines) 
         String.starts_with?(lc_line, "content-transfer-encoding:") -> parse_part_transfer_encoding(multipart_part, encoding, all_lines) 
         String.starts_with?(lc_line, "content-disposition:")       -> parse_part_disposition(multipart_part, encoding, all_lines) 
         String.starts_with?(lc_line, "content-id:")                -> parse_part_content_id(multipart_part, encoding, all_lines) 
         String.starts_with?(lc_line, "content-description:")       -> parse_part_skip(multipart_part, encoding, all_lines) 
         String.starts_with?(lc_line, "mime-version:")              -> parse_part_skip(multipart_part, encoding, all_lines) 
         String.starts_with?(lc_line, "date:")                      -> parse_part_skip(multipart_part, encoding, all_lines) 
         # X- for example X-Attachment-Id or X-Android-Body-Quoted-Part
         String.starts_with?(lc_line, "x-") && String.contains?(lc_line, ":")       -> parse_part_skip(multipart_part, encoding, all_lines) 
         String.starts_with?(lc_line, "content-") && String.contains?(lc_line, ":") -> parse_part_unknown_header(multipart_part, encoding, all_lines) 
         true -> parse_part_finish(multipart_part, encoding, all_lines) 
       end
   end

   def lines_continued(line1, [line2 | otherlines]) do
      # count number of double-quotes, and determine if we are now even or odd
      modules2 = String.codepoints(line1) |> Enum.filter( &(&1 == "\"") ) |> length |> rem(2)
      if modules2 != 0 or line1 =~ ~r/;\s*$/ or line2 =~ ~r/^\t/ do
         lines_continued(line1 <> line2, otherlines)
      else
         {line1, [line2 | otherlines]}
      end 
   end

   def lines_continued(line, otherlines), do: {line, otherlines}

   def parse_part_content_type(multipart_part, encoding, [line | otherlines]) do
       content_type = String.slice(line, String.length("content-type:")..-1)
       {content_type, otherlines} = lines_continued(content_type, otherlines)
       # Logger.debug "      Content-type: " <> content_type
       content_type_parameters = String.split(content_type, ~r/\s*;\s*/)
       multipart_part = parse_content_type_parameters(multipart_part, content_type_parameters)

       parse_part_lines(multipart_part, encoding, otherlines)
   end

   def parse_content_type(multipart_part, content_type) do
       if String.length(content_type) > 0 do
          content_type_parameters = String.split(content_type, ~r/\s*;\s*/)
          multipart_part = parse_content_type_parameters(multipart_part, content_type_parameters)
       end
       multipart_part
   end

   def parse_content_type_parameters(multipart_part, content_type_parameters) do
       media_type = (List.first(content_type_parameters) || "") |> String.strip |> StringUtils.unquoted |> String.downcase

       if String.length(media_type) > 0 do
         multipart_part = %{multipart_part | media_type: media_type}
       end

       boundary_keyval = Enum.find(content_type_parameters, fn(param) -> String.downcase(param) |> String.starts_with?("boundary") end)
       if !is_nil(boundary_keyval) and String.contains?(boundary_keyval, "=") do
         boundary_name = get_value(boundary_keyval) |> String.strip |> StringUtils.unquoted
         multipart_part = %{multipart_part | boundary: boundary_name}
       end

       charset_keyval = Enum.find(content_type_parameters, fn(param) -> String.downcase(param) |> String.starts_with?("charset") end)
       if !is_nil(charset_keyval) and String.contains?(charset_keyval, "=") do
         charset = get_value(charset_keyval) |> String.strip |> StringUtils.unquoted |> String.downcase
         multipart_part = %{multipart_part | charset: charset}
       end

       extract_and_set_filename(multipart_part, content_type_parameters, "name")
   end

   def get_value(key_value) do
       String.replace(key_value, ~r/^[^=]*=/, "")
   end

   def parse_part_content_id(multipart_part, encoding, [line | otherlines]) do
       content_id = String.slice(line, String.length("content-id:")..-1) |> String.strip |> StringUtils.unquoted
       {content_id, otherlines} = lines_continued(content_id, otherlines)
       # Logger.debug "      Content-ID: " <> content_id
       multipart_part = %{multipart_part | content_id: content_id}
       parse_part_lines(multipart_part, encoding, otherlines)
   end

   def parse_part_transfer_encoding(multipart_part, _, [line | otherlines]) do
       encoding = String.slice(line, String.length("content-transfer-encoding:")..-1) |> String.strip |> StringUtils.unquoted
       {encoding, otherlines} = lines_continued(encoding, otherlines)
       # Logger.debug "      Encoding: " <> encoding
       parse_part_lines(multipart_part, encoding, otherlines)
   end

   def parse_part_skip(multipart_part, encoding, [line | otherlines]) do
       {_, otherlines} = lines_continued(line, otherlines)
       # Logger.debug "      Skipped " <> line
       parse_part_lines(multipart_part, encoding, otherlines)
   end

   def parse_part_unknown_header(multipart_part, encoding, [line | otherlines]) do
     {line, otherlines} = lines_continued(line, otherlines)
     Logger.warn "Unknown header line in body ignored: " <> line
     parse_part_lines(multipart_part, encoding, otherlines)
   end

   def parse_part_disposition(multipart_part, encoding, [line | otherlines]) do
       disposition = String.slice(line, String.length("content-disposition:")..-1)
       {disposition, otherlines} = lines_continued(disposition, otherlines)
       # Logger.debug "      Disposition: " <> disposition
       multipart_part = parse_disposition(multipart_part, disposition)
       parse_part_lines(multipart_part, encoding, otherlines)
   end

   def parse_disposition(multipart_part, disposition) do
       if String.length(disposition) > 0 do
          # split on ;
          disposition_parameters = String.split(disposition, ~r/\s*;\s*/)
          if length(disposition_parameters) > 0 do
             type = Enum.at(disposition_parameters, 0) |> String.strip |> String.downcase
             if String.length(type) > 0 do
                is_inline = (type == "inline")
                multipart_part = %{multipart_part | inline: is_inline}
             end
             multipart_part = extract_and_set_filename(multipart_part, disposition_parameters, "filename")
          end
       end
       multipart_part
   end

   def decode(encoding, text) do
       case String.downcase(encoding) do
         "quoted-printable" -> QuotedPrintable.decode(text) |> :erlang.list_to_binary
         "base64" -> to_char_list(text) |> :base64.decode
         # others: for example: 7bit
         _ -> text
       end
   end

   # Content-Disposition: attachment; filename=abc.pdf
   # RFC2231 example
   #   filename*0*=us-ascii'en'This%20is%20even%20more%20
   #   filename*1*=%2A%2A%2Afun%2A%2A%2A%20
   #   filename*2="isn't it!"
   def extract_and_set_filename(multipart_part, content_parameters, parametername) do
       # search for (file)name = value occurrences and concat them 
       name_parts = Enum.filter_map(content_parameters, 
                        fn(param) -> lc_text = String.downcase(param); String.contains?(param, "=") and String.starts_with?(lc_text, parametername) end,
                        fn(key_value) -> { get_param_number(key_value), key_value =~ ~r/^[^=]*\*=/ , get_value(key_value) |> String.strip |> StringUtils.unquoted } end)
       if length(name_parts) > 0 do
         if length(name_parts) > 1 do
            # Parameter continuation: In theory the parameters can be in the wrong order. Never seen it though
            # sort
            name_parts = Enum.sort( name_parts, fn({a,_,_},{b,_,_}) -> a <= b end )
         end
         # RFC2231
         # When the regex above ~r/^[^=]*\*=/ matches filename*= filename*0*= it indicates that there should be encoding 
         {_,with_charset,_} = Enum.at(name_parts, 0)
         filename = Enum.map(name_parts, fn({_,_,val}) -> val end) |> Enum.join
         if with_charset do
            uu_decoded = :erlang.binary_to_list(filename) |> :http_uri.decode |> :erlang.list_to_binary
            decoded_filename = String.split(uu_decoded, "'") |> Enum.drop(2) |> Enum.join("'")
            if String.length(decoded_filename) > 0 do
               filename = decoded_filename
            end
         else
           # RFC2047 can also be used to encode
           # Content-Type: IMAGE/png; NAME="=?UTF-8?B?cjAucG5n?="
           if String.contains?(filename, "?=") do
              decoded_text_list = WordDecoder.decode_text(filename)
              charsets = WordDecoder.get_charsets_besides_ascii(decoded_text_list)
           end
         end
         if String.length(filename) > 0 do
            multipart_part = %{multipart_part | filename: filename}
         end
       end
       multipart_part
   end
   
   def get_param_number(key_value) do
       String.replace(key_value, ~r/^[^=\d]*(\d*)\*?=.*/, "\\1")
   end

end
