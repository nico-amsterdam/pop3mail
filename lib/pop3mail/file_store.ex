defmodule Pop3mail.FileStore do

   @content_type2file_extension %{ "text/plain" => "txt", "text/html" => "html" }
   # store most important header details in header.txt
   def store_mail_header(content, filename_prefix, unsafe_addition, dirname) do
      if String.length(unsafe_addition) > 0 do
         filename = filename_prefix <> "_" <> remove_unwanted_chars(unsafe_addition, 35) <> ".txt"
         path = Path.join(dirname, filename)
         case :file.write_file(path, content) do
            :ok -> :ok
            {:error, _} -> store_mail_header(content, filename_prefix, "", dirname)
         end
      else
         path = Path.join(dirname, filename_prefix <> ".txt")
         :file.write_file(path, content)
      end
   end
   
   # store_raw
   def store_raw(mail_content, dirname) do
         :file.write_file(Path.join(dirname, "raw.txt"), mail_content)
   end
   
   def mkdir(base_dir, name, unsafe_addition) do
      if String.length(unsafe_addition) > 0 do
          shortened_unsafe_addition = remove_unwanted_chars(unsafe_addition, 22)
          dirname = Path.join( base_dir , name <> "_" <> shortened_unsafe_addition)
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
   def store_part(multipart_part, base_dir) do
     dirname = Path.join(base_dir, multipart_part.path)
     unless File.dir?(dirname), do: File.mkdir_p! dirname 
     pathname = Path.join(dirname,  remove_unwanted_chars(multipart_part.filename, 50))
     if String.starts_with?(multipart_part.media_type, "text/") and get_line_separator() != '\r\n' do
        # store text file in unix format
        multipart_part = dos2unix(multipart_part)
     end
     # IO.inspect pathname
     # file.write_file does not attempt encoding conversions
     # It's not very safe, does accept any pathname. Don't run this as root.
     :file.write_file(pathname, multipart_part.content)
   end
   
   def get_line_separator() do
      # in theory :io_lib.nl() should return '\r\n' on windows, but it's not.
      case :os.type() do
         { :win32, _ } -> "\r\n"
         _ -> :io_lib.nl() |> to_string
      end
   end

   def dos2unix(multipart_part) do
      line_sep = get_line_separator()
      unix_text = multipart_part.content |> String.split("\r\n") |> Enum.join(line_sep)
      %{multipart_part | content: unix_text}
   end

   # characters we don't want in filenames can be filtered out with this function.
   def remove_unwanted_chars(text, max_chars) do
      # I don't like spaces in filenames. file can contain dash - but should not start with it.
      String.replace(text, "@", " at ") |> String.replace(~r/\s+/u, "_") |> String.replace(~r/[^A-Za-z0-9\x80-\xFF_.-]/u , "") |> String.replace_prefix("-", "") |> String.slice(0..max_chars) 
   end

   def get_default_filename(media_type, charset, index) do
        file_extension = @content_type2file_extension[media_type] || String.split(media_type, "/") |> List.last
        filename = "message" <> to_string(index)
        lc_charset = String.downcase(charset)
        if lc_charset != "us-ascii" do
           filename = filename <> "." <> lc_charset
        end
        filename <> "." <> file_extension
   end

   def set_default_filename(multipart_part) do
        filename = get_default_filename(multipart_part.media_type, multipart_part.charset, multipart_part.index)
        %{multipart_part | filename: filename}
   end

end
