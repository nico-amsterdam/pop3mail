defmodule Pop3mail.FileStore do

   @moduledoc "Store header, messages and attachments on the filesystem."

   @content_type2file_extension %{"text/plain" => "txt", "text/html" => "html"}
   # store most important header details in header.txt

   @doc """
   Store mail header.

   filename is `filename_prefix` . `unsafe_addition` . txt

   `unsafe_addition` - append this to the filename.
   It will be truncated at 35 characters.
   Unusual characters for the filesystem will be filtered out. If storing with unsafe_addition fails, the file will be stored without it.
   """
   @spec store_mail_header(String.t, String.t, binary, String.t) :: {:ok, String.t} | {:error, String.t, String.t}
   def store_mail_header(content, filename_prefix, unsafe_addition, dirname) do
      if String.length(unsafe_addition) > 0 do
         filename = filename_prefix <> "." <> remove_unwanted_chars(unsafe_addition, 35) <> ".txt"
         path = Path.join(dirname, filename)
         case :file.write_file(path, content) do
            :ok -> {:ok, path}
            {:error, _} -> store_mail_header(content, filename_prefix, "", dirname)
         end
      else
         path = Path.join(dirname, filename_prefix <> ".txt")
         write_file(path, content)
      end
   end

   @doc "store raw email"
   @spec store_raw(String.t, String.t, String.t) :: {:ok, String.t} | {:error, String.t, String.t}
   def store_raw(mail_content, filename, dirname) do
     path = Path.join(dirname, filename)
     write_file(path, mail_content)
   end

   @doc """
   make directory. Returns created directory name full path.

   directory is `base_dir` / `name` - `unsafe_addition`

   `unsafe_addition` - append this to the directory name.
   It will be truncated at 45 characters.
   Unusual characters for the filesystem will be filtered out. If creating the directory with unsafe_addition fails, the directory will be created without it.
   """
   @spec mkdir(String.t, String.t, binary) :: String.t
   def mkdir(base_dir, name, unsafe_addition) do
      if String.length(unsafe_addition) > 0 do
          shortened_unsafe_addition = remove_unwanted_chars(unsafe_addition, 45)
          dirname = Path.join(base_dir, name <> "-" <> shortened_unsafe_addition)
          if File.dir?(dirname) do
             dirname
          else
             # check if the operating system is able to create this directory, if not, try without unsafe addition
             case File.mkdir(dirname) do
               :ok -> dirname
               {:error, _} -> mkdir(base_dir, name, "")  # drop the unsafe addition and re-try
             end
          end
      else
          dirname = Path.join(base_dir, name)
          unless File.dir?(dirname), do: File.mkdir!(dirname)
          dirname
      end
   end

   # store body content
   @doc """
   store one part of the body.

   Text files (media types text/plain, text/html for example) will be converted from dos to unix format on non-windows platforms.

   `multipart_part` - a Pop3mail.Part
   """
   @spec store_part(Pop3mail.Part.t, String.t) :: {:ok, String.t} | {:error, String.t, String.t}
   def store_part(multipart_part, base_dir) do
     dirname = Path.join(base_dir, multipart_part.path)
     unless File.dir?(dirname), do: File.mkdir_p! dirname

     # this is also protection against filenames like: /etc/passwd
     safe_filename = remove_unwanted_chars(multipart_part.filename, 50)
     safe_filename = if safe_filename == "", do: "unknown", else: safe_filename
     path = Path.join(dirname, safe_filename)
     text_on_unix = String.starts_with?(multipart_part.media_type, "text/") and get_line_separator() != '\r\n'
     # if unix, store text file in unix format
     multipart_part = if text_on_unix, do: dos2unix(multipart_part), else: multipart_part
     write_file(path, multipart_part.content)
   end

   # write file and return either {:ok, path} or {:error, reason, path}
   defp write_file(path, content) do
     # file.write_file does not attempt encoding conversions
     # It's not very safe, does accept any path. Don't run this as root.
     case :file.write_file(path, content) do
        :ok -> {:ok, path}
        {:error, reason} -> {:error, reason, path}
     end
   end

   @doc "get line seperator for text files. On windows/dos this is carriage return + linefeed, on other platforms it is just the linefeed."
   @spec get_line_separator() :: String.t
   def get_line_separator() do
      # in theory :io_lib.nl() should return '\r\n' on windows, but it's not.
      case :os.type() do
         {:win32, _} -> "\r\n"
         _ -> :io_lib.nl() |> to_string
      end
   end

   @doc """
   Convert a part's content text from dos-format (with carriage return + linefeed after each line) to unix-format (with just the linefeed).

   `multipart_part` - a Pop3mail.Part
   """
   @spec dos2unix(Pop3mail.Part.t) :: Pop3mail.Part.t
   def dos2unix(multipart_part) do
      line_sep = get_line_separator()
      unix_text = multipart_part.content |> String.splitter("\r\n") |> Enum.join(line_sep)
      %{multipart_part | content: unix_text}
   end

   # characters we don't want in filenames can be filtered out with this function.
   @doc """
   Remove characters which are undesirable for filesystems (like \\ / : * ? " < > | [ ] and control characters)
   """
   @spec remove_unwanted_chars(binary, integer) :: String.t
   def remove_unwanted_chars(text, max_chars) do
      # Remove all control characters. Windows doesn't like: \ / : * ? " < > | and dots or spaces at the start/end.
      if String.printable?(text) do
        # for utf-8 compatible text we accept more than just the 7bit ascii range.
        # It's not perfect, this code can give funny results if the text isn't utf-8 compatible
        text
        |> String.replace(~r/[\x00-\x1F\x7F:\?\[\]\<\>\|\*\"\/\\]/u, "")
        |> String.replace(~r/\s+/u, " ")
        |> String.replace(~r/^[\s\.]+/u, "")
        |> String.slice(0, max_chars)
        |> String.replace(~r/[\s\.]+$/u, "")
      else
        # only return 7bit ascii characters.
        # It's not perfect, this code can give funny results if feed with multibyte content.
        text
        |> String.replace(~r/[^0-9;=@A-Z_a-z !#$%&\(\)\{\}\+\.,\-~`^]/ , "")
        |> String.replace(~r/\s+/, " ")
        |> String.replace(~r/^[\s\.]+/, "")
        |> String.slice(0, max_chars)
        |> String.replace(~r/[\s\.]+$/, "")
      end
   end

   @doc """
   Construct a filename for an email message.

   filename will be: 'message' . <charset if not us-ascii> . <extension based on media_type>

   The default file extenstion for text/plain is .txt
   In other cases the last part of the `media_type` wil be used as extension.
   """
   @spec get_default_filename(String.t, String.t, integer) :: String.t
   def get_default_filename(media_type, charset, index) do
        file_extension = @content_type2file_extension[media_type] || (media_type |> String.split("/") |> List.last)
        filename = "message" <> to_string(index)
        lc_charset = String.downcase(charset)
        filename = if lc_charset != "us-ascii", do: filename <> "." <> lc_charset, else: filename
        filename <> "." <> file_extension
   end

   @doc """
   set default filename in the `multipart_part`.

   Calls FileStore.get_default_filename to get the default filename.

   `multipart_part` - a Pop3mail.Part
   """
   @spec set_default_filename(Pop3mail.Part.t) :: Pop3mail.Part.t
   def set_default_filename(multipart_part) do
        filename = get_default_filename(multipart_part.media_type, multipart_part.charset, multipart_part.index)
        %{multipart_part | filename: filename}
   end

end
