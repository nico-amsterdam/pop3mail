defmodule Pop3mail.Multipart do
  alias Pop3mail.Part
  alias Pop3mail.StringUtils
  alias Pop3mail.QuotedPrintable
  alias Pop3mail.WordDecoder
  alias Pop3mail.Base64Decoder

  require Logger


  @moduledoc """
  Parser for: RFC 2045 Multipart content type (previously RFC 1341).

  It works recursive because a multipart content can contain other multiparts.
  The returned sequential list of Pop3mail.Path structs is flattened. The Part.path field shows where it is in the hierarchy.
  This module can also be useful to parse RFC 7578 multipart/form-data (previously RFC 2388).
  """

   @doc """
   Parse multipart content. Returns a flattened list of Pop3mail.Part's

   This is recursively called for each multipart part, e.g. parse_content calls itself

   `multipart_part` - Pop3mail.Part input.
   """
   @spec parse_content(Part.t) :: list(Part.t) 
   def parse_content(multipart_part) do
      if is_multipart?(multipart_part) do
         extra_path  = multipart_part.media_type |> String.split("/") |> List.last
         new_path    = Path.join(multipart_part.path, extra_path)
         # Logger.info "    Process multipart: #{new_path}"
         top_level_multipart_part_list = parse_multipart(multipart_part.boundary, multipart_part.content, new_path)

         # multiparts can contain other multiparts, go deeper
         l = Enum.flat_map(top_level_multipart_part_list, &(parse_content(&1)))
         l
      else
         # ready
         [multipart_part]
      end
   end

   @doc """
   Is this part a multipart? Looks if the media_type starts with multipart/.

   It could be multipart/alternative, multipart/relative or multipart/mixed.

   `multipart_part` - Pop3mail.Part
   """
   @spec is_multipart?(Part.t) :: boolean
   def is_multipart?(multipart_part) do
      multipart_part.media_type
      |> String.downcase
      |> String.starts_with?("multipart/")
   end

   @doc """
   Parse the boundary in the multipart content.

   * `raw_content` - multipart content
   * `boundary_name` - multipart boundary to search for
   * `path` - path in the multipart hierarchy. For example: relative/alternative
   """
   @spec parse_multipart(String.t, String.t, String.t) :: list(Part.t)
   def parse_multipart(boundary_name, raw_content, path) do
     # get text till end boundary
     multipart_list = String.split(raw_content, "--" <> boundary_name <> "--")
     multipart = Enum.at(multipart_list, 0)
     # split at --boundary
     [_ | parts] = String.split(multipart, "--" <> boundary_name <> "\r\n")
     if parts == [] do
        Logger.warn "    Boundary #{boundary_name} not found."
        []
     else
        if length(multipart_list) <= 1, do: Logger.warn "    End boundary #{boundary_name} not found."
        if length(multipart_list)  > 2, do: Logger.warn "    Multiple end boundaries #{boundary_name} found."
        parts |> Enum.with_index(1) |> Enum.flat_map(&(parse_part(&1, boundary_name, path)))
     end
   end

   # We could split all the lines at once, but with large attachments this consumes a lot of memory 
   # Instead, we only split a line when needed
   defp lazy_line_split(lines) do
      String.split(lines, "\r\n", parts: 2)
   end

   @doc """
   Parse a part of the multipart content.

   * `{part, index}` - Numbered part content. Index starts at 1 for part 1 in a multipart.
   * `boundary_name` - multipart boundary name
   * `path` - path in the multipart hierarchy. For example: relative/alternative
   """
   @spec parse_part({String.t, integer}, String.t, String.t) :: list(Part.t)
   def parse_part({part, index}, boundary_name, path) do
     # bare carriage returns or bare linefeeds are not allowed in email.
     [line1 | otherlines] = lazy_line_split(part)
     new_part = %Part{boundary: boundary_name, path: path, index: index}
     multipart_part = parse_part_lines(new_part, "raw", [line1 | otherlines])
     # return list of parts
     [multipart_part]
   end

   @doc """
   Decode lines and add them as content in the multipart part. Returns a Pop3mail.Part

   Is called after all multipart header lines are parsed.

   * `multipart_part` - Pop3mail.Part input
   * `encoding` - For example: base64, quoted-printable, 7bit, 8bit, etc.
   * `lines` - part content splitted in lines
   """
   @spec parse_part_decode(Part.t, String.t, list(String.t)) :: Part.t
   def parse_part_decode(multipart_part, encoding, lines) do
     content = decode_lines(encoding, lines)
     %{multipart_part | content: content}
   end

   @doc """
   Return decoded lines as binary.

   `encoding` - For example: base64, quoted-printable, 7bit, 8bit, etc.
   """
   @spec decode_lines(String.t, list(String.t)) :: String.t
   def decode_lines(encoding, lines) do
     decode(encoding, Enum.join(lines, "\r\n"))
   end

   @doc """
   Finish parsing multipart header lines and start decode of the part content. Returns a Pop3mail.Part

   * `multipart_part` - Pop3mail.Part input
   * `encoding` - For example: base64, quoted-printable, 7bit, 8bit, etc.
   * `list` - lines
   """
   @spec parse_part_finish(Part.t, String.t, list(String.t)) :: Part.t
   def parse_part_finish(multipart_part, encoding, [line | otherlines]) do
     # there should be an empty line after the headers
     otherlines =
        if String.length(String.trim(line)) > 0 do
           # this is not always the case or we have an unknown header here.
           Logger.warn "    Missing newline or unknown header in body" <> StringUtils.printable(" at line: " <> line)
           # fix; don't skip line
           [line | otherlines]
        else
           otherlines
        end
     parse_part_decode(multipart_part, encoding, otherlines)
   end

   @doc """
   Parse multipart header lines. Returns a Pop3mail.Part

   * `multipart_part` - Pop3mail.Part input
   * `encoding` - For example: base64, quoted-printable, 7bit, 8bit, etc.
   * `list` - lines
   """
   @spec parse_part_lines(Part.t, String.t, list(String.t)) :: Part.t
   def parse_part_lines(multipart_part, encoding, []) do
       # [] when all header lines are read and there are no more lines. There is no part content!
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
         String.starts_with?(lc_line, "content-location:")          -> parse_part_content_location(multipart_part, encoding, all_lines)
         is_skip_header(lc_line)                                    -> parse_part_skip(multipart_part, encoding, all_lines)
         is_unknown_header(lc_line)                                 -> parse_part_unknown_header(multipart_part, encoding, all_lines)
         true -> parse_part_finish(multipart_part, encoding, all_lines)
       end
   end

   # Analyze multipart header not parsed by other functions. Assume it's an unknown header if it starts with 'content-'
   defp is_unknown_header(lc_line) do
      String.starts_with?(lc_line, "content-") && String.contains?(lc_line, ":")
   end

   # Some multipart headers are not interesting for pop3mail. Skip them.
   # `lc_line` - lowercased line
   defp is_skip_header(lc_line) do
      String.starts_with?(lc_line, "content-description:") ||
      String.starts_with?(lc_line, "mime-version:")        ||
      String.starts_with?(lc_line, "date:")                ||
      (String.starts_with?(lc_line, "x-") && String.contains?(lc_line, ":")) # X- for example X-Attachment-Id or X-Android-Body-Quoted-Part
   end

   @doc "A multipart header line can continue on the next line. When next line starts with a tab-character or when there is a opening double quote not closed yet."
   @spec lines_continued(String.t, list(String.t)) :: {String.t, list(String.t)}
   def lines_continued(line1, []), do: {line1, []}

   def lines_continued(line1, [more_lines | even_more]) do
      [line2 | otherlines] = lazy_line_split(more_lines)
      # count number of double-quotes, and determine if we are now even or odd
      modules2 = line1
                 |> String.codepoints
                 |> Enum.filter(&(&1 == "\""))
                 |> length
                 |> rem(2)
      if modules2 != 0 or line1 =~ ~r/;\s*$/ or line2 =~ ~r/^\t/ do
         lines_continued(line1 <> line2, otherlines ++ even_more)
      else
         {line1, [line2 | otherlines ++ even_more]}
      end
   end

   @doc """
   Parse multipart Content-Type header line. It can contain media_type, charset, (file-)name and boundary. Returns a Pop3mail.Part

   * `multipart_part` - Pop3mail.Part input
   * `encoding` - For example: base64, quoted-printable, 7bit, 8bit, etc.
   * `list` - lines
   """
   @spec parse_part_content_type(Part.t, String.t, list(String.t)) :: Part.t
   def parse_part_content_type(multipart_part, encoding, [line | otherlines]) do
       content_type = String.slice(line, String.length("content-type:")..-1)
       {content_type, split_lines} = lines_continued(content_type, otherlines)
       # Logger.debug "      Content-type: " <> content_type
       content_type_parameters = String.split(content_type, ~r/\s*;\s*/)
       multipart_part = parse_content_type_parameters(multipart_part, content_type_parameters)

       parse_part_lines(multipart_part, encoding, split_lines)
   end

   @doc """
   Parse multipart Content-Type header line. It can contain media_type, charset, (file-)name and boundary. Returns a Pop3mail.Part

   `multipart_part` - Pop3mail.Part input
   """
   @spec parse_content_type(Part.t, String.t) :: Part.t 
   def parse_content_type(multipart_part, content_type) do
      if String.length(content_type) > 0 do
         content_type_parameters = String.split(content_type, ~r/\s*;\s*/)
         parse_content_type_parameters(multipart_part, content_type_parameters)
      else
         multipart_part
      end
   end

   @doc """
   Parse value of content-type header line. It can contain media_type, charset, (file-)name and boundary. Returns a Pop3mail.Part

   * `multipart_part` - Pop3mail.Part input
   * `content_type_parameters` - list of parameters in the format key=value
   """
   @spec parse_content_type_parameters(Part.t, list(String.t)) :: Part.t
   def parse_content_type_parameters(multipart_part, content_type_parameters) do
       first_content_type_parameter =  List.first(content_type_parameters) || ""
       media_type = first_content_type_parameter
                    |> String.trim
                    |> StringUtils.unquoted
                    |> String.downcase

       multipart_part =
          case String.length(media_type) > 0 do
             true  -> %{multipart_part | media_type: media_type}
             false -> multipart_part
          end

       boundary_keyval = Enum.find(content_type_parameters,
          fn(param) -> param |> String.downcase |> String.starts_with?("boundary") end)
       multipart_part = set_boundary(multipart_part, boundary_keyval)

       charset_keyval = Enum.find(content_type_parameters,
          fn(param) -> param |> String.downcase |> String.starts_with?("charset") end)
       multipart_part = set_charset(multipart_part, charset_keyval)

       extract_and_set_filename(multipart_part, content_type_parameters, "name")
   end

   # set multipart_part.boundary if available
   defp set_boundary(multipart_part, boundary_keyval) do
      case StringUtils.contains?(boundary_keyval, "=") do
        true  ->
           value = get_value(boundary_keyval)
           boundary_name = value |> String.trim |> StringUtils.unquoted
           %{multipart_part | boundary: boundary_name}
        false -> multipart_part
      end
   end

   # set multipart_part.charset if available
   defp set_charset(multipart_part, charset_keyval) do
      case StringUtils.contains?(charset_keyval, "=") do
        true  ->
           value = get_value(charset_keyval)
           charset = value |> String.trim |> StringUtils.unquoted |> String.downcase
           %{multipart_part | charset: charset}
        false -> multipart_part
      end
   end

   @doc "Get value of key_value. `key_value` - format must be: key=value or key*<number>*=value or key*=value."
   @spec get_value(String.t) :: String.t
   def get_value(key_value) do
       String.replace(key_value, ~r/^[^=]*=/, "")
   end

   @doc """
   Parse multipart Content-ID header line. Returns a Pop3mail.Part

   * `multipart_part` - Pop3mail.Part input
   * `encoding` - For example: base64, quoted-printable, 7bit, 8bit, etc.
   * `list` - lines
   """
   @spec parse_part_content_id(Part.t, String.t, list(String.t)) :: Part.t
   def parse_part_content_id(multipart_part, encoding, [line | otherlines]) do
       content_id = line
                    |> String.slice(String.length("content-id:")..-1)
                    |> String.trim
                    |> StringUtils.unquoted
       {content_id, split_lines} = lines_continued(content_id, otherlines)
       # Logger.debug "      Content-ID: " <> content_id
       multipart_part = %{multipart_part | content_id: content_id}
       parse_part_lines(multipart_part, encoding, split_lines)
   end

   @doc """
   Parse multipart Content-Location header line as defined in RFC 2557. Returns a Pop3mail.Part

   * `multipart_part` - Pop3mail.Part input
   * `encoding` - For example: base64, quoted-printable, 7bit, 8bit, etc.
   * `list` - lines
   """
   @spec parse_part_content_location(Part.t, String.t, list(String.t)) :: Part.t
   def parse_part_content_location(multipart_part, encoding, [line | otherlines]) do
       content_location = line
                          |> String.slice(String.length("content-location:")..-1)
                          |> String.trim
                          |> StringUtils.unquoted
       {content_location, split_lines} = lines_continued(content_location, otherlines)
       # Logger.debug "      Content-Location: " <> content_location
       multipart_part = %{multipart_part | content_location: content_location}
       parse_part_lines(multipart_part, encoding, split_lines)
   end

   @doc """
   Parse multipart Content-Transfer-Encoding header line. Returns a Pop3mail.Part

   * `multipart_part` - Pop3mail.Part input
   * `encoding` - For example: base64, quoted-printable, 7bit, 8bit, etc.
   * `list` - lines
   """
   @spec parse_part_transfer_encoding(Part.t, String.t, list(String.t)) :: Part.t
   def parse_part_transfer_encoding(multipart_part, _, [line | otherlines]) do
       encoding = line
                  |> String.slice(String.length("content-transfer-encoding:")..-1)
                  |> String.trim
                  |> StringUtils.unquoted
       {encoding, split_lines} = lines_continued(encoding, otherlines)
       # Logger.debug "      Encoding: " <> encoding
       parse_part_lines(multipart_part, encoding, split_lines)
   end

   @doc """
   Ignore a multipart header line. Returns a Pop3mail.Part

   * `multipart_part` - Pop3mail.Part input
   * `encoding` - For example: base64, quoted-printable, 7bit, 8bit, etc.
   * `list` - lines
   """
   @spec parse_part_skip(Part.t, String.t, list(String.t)) :: Part.t
   def parse_part_skip(multipart_part, encoding, [line | otherlines]) do
       {_, split_lines} = lines_continued(line, otherlines)
       # Logger.debug "      Skipped " <> line
       parse_part_lines(multipart_part, encoding, split_lines)
   end

   @doc """
   Skip an unknown multipart header line. Logs a warning. Returns a Pop3mail.Part

   * `multipart_part` - Pop3mail.Part input
   * `encoding` - For example: base64, quoted-printable, 7bit, 8bit, etc.
   * `list` - lines
   """
   @spec parse_part_unknown_header(Part.t, String.t, list(String.t)) :: Part.t
   def parse_part_unknown_header(multipart_part, encoding, [line | otherlines]) do
     {line, split_lines} = lines_continued(line, otherlines)
     Logger.warn "    Unknown header line in body ignored" <> StringUtils.printable(": " <> line)
     parse_part_lines(multipart_part, encoding, split_lines)
   end

   @doc """
   Parse multipart Content-Disposition header line. Returns a Pop3mail.Part

   * `multipart_part` - Pop3mail.Part input
   * `encoding` - For example: base64, quoted-printable, 7bit, 8bit, etc.
   * `list` - lines
   """
   @spec parse_part_disposition(Part.t, String.t, list(String.t)) :: Part.t
   def parse_part_disposition(multipart_part, encoding, [line | otherlines]) do
       disposition = String.slice(line, String.length("content-disposition:")..-1)
       {disposition, split_lines} = lines_continued(disposition, otherlines)
       # Logger.debug "      Disposition: " <> disposition
       multipart_part = parse_disposition(multipart_part, disposition)
       parse_part_lines(multipart_part, encoding, split_lines)
   end

   @doc """
   Parse multipart Content-Disposition header line. This is either inline or attachment, and it can contain a filename. Returns a Pop3mail.Part

   `multipart_part` - Pop3mail.Part input
   """
   @spec parse_disposition(Part.t, String.t) :: Part.t
   def parse_disposition(multipart_part, disposition) do
       if StringUtils.is_empty?(disposition) do
          multipart_part
       else
          # split on ;
          disposition_parameters = String.split(disposition, ~r/\s*;\s*/)
          case length(disposition_parameters) > 0 do
             true  -> parse_disposition_parameters(multipart_part, disposition_parameters)
             false -> multipart_part
          end
       end
   end

   @doc """
   Parse value of Content-Disposition header line. This is either inline or attachment, and it can contain a filename. Returns a Pop3mail.Part

   * `multipart_part` - Pop3mail.Part input
   * `disposition_parameters` - list of parameters in the format key=value
   """
   @spec parse_disposition_parameters(Part.t, list(String.t)) :: Part.t
   def parse_disposition_parameters(multipart_part, disposition_parameters) do
      type = disposition_parameters
             |> Enum.at(0)
             |> String.trim
             |> String.downcase
      multipart_part =
         if String.length(type) > 0 do
            is_inline = (type == "inline")
            %{multipart_part | inline: is_inline}
         else
            multipart_part
         end
      extract_and_set_filename(multipart_part, disposition_parameters, "filename")
   end

   @doc """
   Return decoded text as binary.

   `encoding` - For example: base64, quoted-printable, 7bit, 8bit, etc.
   """
   @spec decode(String.t, String.t) :: binary
   def decode(encoding, text) do
       case String.downcase(encoding) do
         "quoted-printable" -> text
                               |> QuotedPrintable.decode
                               |> :erlang.list_to_binary
         "base64" -> decode_base64!(text)
         # others: for example: 7bit
         _ -> text
       end
   end

   @doc """
   Return decoded text as binary.

   `text` - base64 encoded text.
   """
   @spec decode_base64!(String.t) :: binary
   def decode_base64!(text) do
     try do
        Base64Decoder.decode!(text)
     rescue
        _ -> Logger.warn("    Invalid encoded base64 content. Please check.")
             "ERROR: invalid base64 encoded text:\n" <> text
     end
   end

   @doc ~S"""
   Extract (file-)name from Content-Disposition value or Content-Type value. Returns Pop3mail.Part with filled-in filename and filename_charset.

   Example of Content-Disposition header line:

     Content-Disposition: attachment; filename=abc.pdf

   RFC 2231 example:

     filename\*0\*=us-ascii'en'This%20is%20even%20more%20<br>
     filename\*1\*=%2A%2A%2Afun%2A%2A%2A%20<br>
     filename\*2="isn't it!"
   """
   @spec extract_and_set_filename(Part.t, list(String.t), String.t) :: Part.t
   def extract_and_set_filename(multipart_part, content_parameters, parametername) do
       # search for (file)name = value occurrences and concat them

       name_parts = content_parameters
                  |> Enum.filter(fn(param) -> String.contains?(param, "=") and 
                                              String.starts_with?(String.downcase(param), parametername) end)
                  |> Enum.map(&map_parameter(&1))
       case length(name_parts) > 0 do
          true  -> extract_and_set_filename_from_name_parts(multipart_part, name_parts)
          false -> multipart_part
       end
   end

   # return {parameter number if any, with charset true/false, unquoted value}
   defp map_parameter(key_value) do
      param_number = get_param_number(key_value)
      with_charset = (key_value =~ ~r/^[^=]*\*=/)
      value = get_value(key_value)
      unquoted_value = value
                       |> String.trim
                       |> StringUtils.unquoted
      {param_number, with_charset, unquoted_value}
   end

   @doc "Get parameter number of key_value. `key_value` - format must be: key=value or key*<parameter number>*=value or key*=value. Returns string. Can be empty."
   @spec get_param_number(String.t) :: String.t
   def get_param_number(key_value) do
      String.replace(key_value, ~r/^[^=\d]*(\d*)\*?=.*/, "\\1")
   end

   # Extract (file-)name from (file-)name list (together one value). Returns Pop3mail.Part with filled-in filename and filename_charset.
   defp extract_and_set_filename_from_name_parts(multipart_part, name_parts) do
      charset = ""
      name_parts = sort_name_parts(name_parts)
      # RFC 2231
      # When the regex above ~r/^[^=]*\*=/ matches filename*= or filename*0*= it indicates that there should be encoding
      {_, with_charset, _} = Enum.at(name_parts, 0)
      filename = name_parts
                 |> Enum.map(fn({_, _, val}) -> val end)
                 |> Enum.join
      {filename, charset} = decode_filename_and_charset(filename, charset, with_charset)
      if String.length(filename) > 0 do
         multipart_part = %{multipart_part | filename: filename}
         case String.length(charset) > 0 do
           true  -> %{multipart_part | filename_charset: charset}
           false -> multipart_part
         end
      else
        multipart_part
      end
   end

   # Sort numbered parameter continuation.
   # In theory the parameters can be in the wrong order. Never seen it though.
   # Sort them anyway.
   defp sort_name_parts(name_parts) do
      case length(name_parts) > 1 do
         true  -> Enum.sort(name_parts, fn({a, _, _}, {b, _, _}) -> a <= b end)
         false -> name_parts
      end
   end

   # return decoded filename and charset if available
   defp decode_filename_and_charset(filename, charset, with_charset) do
     if with_charset do
        {decoded_filename, decoded_charset} = decoded_extended_filename_and_charset(filename)
        case String.length(decoded_filename) > 0 do
           true  -> {decoded_filename, decoded_charset}
           false -> {filename, charset}
        end
     else
       # RFC 2047 can also be used to encode, for example:
       # Content-Type: IMAGE/png; NAME="=?UTF-8?B?cjAucG5n?="
       case String.contains?(filename, "=?") do
          true  -> decoded_word_filename_and_charset(filename)
          false -> {filename, charset}
       end
     end
   end

   # content-type name can be an encoded-word. A bit unusual nowadays.
   defp decoded_word_filename_and_charset(filename) do
      decoded_text_list = WordDecoder.decode_text(filename)
      charsets = WordDecoder.get_charsets_besides_ascii(decoded_text_list)
      charset = Enum.join(charsets, "_")
      filename = WordDecoder.decoded_text_list_to_string(decoded_text_list)
      {filename, charset}
   end

   # decode filename that is in the format: <optional charset> ' <optional language code> ' url encoded text
   # RFC 2231, extended-initial-value
   defp decoded_extended_filename_and_charset(filename) do
      uu_decoded = filename
                   |> :erlang.binary_to_list
                   |> :http_uri.decode
                   |> :erlang.list_to_binary
      splitted = String.split(uu_decoded, "'")
      decoded_filename = splitted |> Enum.drop(2) |> Enum.join("'")
      filename_charset = Enum.at(splitted, 0)
      {decoded_filename, filename_charset}
   end

end
