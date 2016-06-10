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
   def mkdir(base_dir, name, unsafe_addition) do
      if String.length(unsafe_addition) > 0 do
          shortened_unsafe_addition = remove_unwanted_chars(unsafe_addition, 45)
          dirname = Path.join(base_dir, name <> "-" <> shortened_unsafe_addition)
          if !File.dir?(dirname) do
              # check if the operating system is able to create this directory, if not, try without unsafe addition
              dirname = 
                  case File.mkdir(dirname) do
                    :ok -> dirname
                    {:error, _} -> mkdir(base_dir, name, "")  # drop the unsafe addition and re-try
                  end
          end
          dirname
       else
          dirname = Path.join(base_dir , name)
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
   def store_part(multipart_part, base_dir) do
     dirname = Path.join(base_dir, multipart_part.path)
     unless File.dir?(dirname), do: File.mkdir_p! dirname 
     path = Path.join(dirname,  remove_unwanted_chars(multipart_part.filename, 50))
     if String.starts_with?(multipart_part.media_type, "text/") and get_line_separator() != '\r\n' do
        # store text file in unix format
        multipart_part = dos2unix(multipart_part)
     end
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
   def dos2unix(multipart_part) do
      line_sep = get_line_separator()
      unix_text = multipart_part.content |> String.split("\r\n") |> Enum.join(line_sep)
      %{multipart_part | content: unix_text}
   end

   # characters we don't want in filenames can be filtered out with this function.
   @doc """
   Remove characters which are undesirable for filesystems (like \ / : * ? " < > | [ ] and control characters)
   """
   def remove_unwanted_chars(text, max_chars) do
      # Remove all control characters. Windows doesn't like: \ / : * ? " < > | and dots add the end.
      if String.printable?(text) do
        # for utf-8 compatible text we accept more than just the 7bit ascii range.
        text
        |> String.replace(~r/\s+/u, " ")
        |> String.replace(~r/[\x00-\x1F\x7F:\?\[\]\<\>\|\*\"\/\\]/u, "")
        |> String.slice(0..max_chars)
        |> String.strip(?.)
      else
        # only return 7bit ascii characters.
        # It's not perfect, this code can give funny results if feed with multibyte content.
        text 
        |> String.replace(~r/\s+/, " ")
        |> String.replace(~r/[^0-9;=@A-Z_a-z !#$%&\(\)\{\}\+\.,\-~`^]/ , "") 
        |> String.slice(0..max_chars) 
        |> String.strip(?.)
      end
   end

   @doc """
   Construct a filename for an email message.

   filename will be: 'message' . <charset if not us-ascii> . <extension based on media_type>

   The default file extenstion for text/plain is .txt
   In other cases the last part of the `media_type` wil be used as extension.
   """
   def get_default_filename(media_type, charset, index) do
        file_extension = @content_type2file_extension[media_type] || (media_type |> String.split("/") |> List.last)
        filename = "message" <> to_string(index)
        lc_charset = String.downcase(charset)
        if lc_charset != "us-ascii" do
           filename = filename <> "." <> lc_charset
        end
        filename <> "." <> file_extension
   end

   @doc """
   set default filename in the `multipart_part`. 
   
   Calls FileStore.get_default_filename to get the default filename.

   `multipart_part` - a Pop3mail.Part
   """
   def set_default_filename(multipart_part) do
        filename = get_default_filename(multipart_part.media_type, multipart_part.charset, multipart_part.index)
        %{multipart_part | filename: filename}
   end

end
