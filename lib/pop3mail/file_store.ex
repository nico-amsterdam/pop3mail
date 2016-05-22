defmodule Pop3mail.FileStore do

   @content_type2file_extension %{ "text/plain" => "txt", "text/html" => "html" }
   # store most important header details in header.txt
   def store_mail_header(content, filename, dirname) do
     path = Path.join(dirname, filename)
     :file.write_file(path, content)
   end
   
   # store_raw
   def store_raw(mail_content, dirname) do
         :file.write_file(Path.join(dirname, "raw.txt"), mail_content)
   end

   # store body content
   def store_part(multipart_part, base_dir) do
     dirname = Path.join(base_dir, multipart_part.path)
     unless File.dir?(dirname), do: File.mkdir_p! dirname 
     pathname = Path.join(dirname,  remove_unwanted_chars(multipart_part.filename, 50))
     if String.starts_with?(multipart_part.media_type, "text/") and :io_lib.nl() != '\r\n' do
        # store text file in unix format
        multipart_part = dos2unix(multipart_part)
     end
     # IO.inspect pathname
     # file.write_file does not attempt encoding conversions
     # It's not very safe, does accept any pathname. Don't run this as root.
     :file.write_file(pathname, multipart_part.content)
   end

   def dos2unix(multipart_part) do
      line_sep = :io_lib.nl() |> to_string
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
