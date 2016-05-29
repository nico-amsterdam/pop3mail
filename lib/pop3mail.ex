defmodule Pop3mail do

   @moduledoc """
   Download email and save to disk. Uses Erlang epop client.
   Handles multipart body. Saves header, body text and attachments.
   Decodes base64 and quoted printable text.
   Decodes encoded words in headers.

   Runs as CLI utility.
   """

   @doc "Call main optionally with username and password. E.g. main([\"--username=a.b@gmail.com\", \"--password=secret\"])"
   def downloader_cli(args) do
      Pop3mail.DownloaderCLI.main(args)
   end

   def header_lookup(header_list, header_name) do
      Pop3mail.Header.lookup(header_list, header_name)
   end

   def decode_header_text(text) do
      Pop3mail.HeaderDecoder.decode_text(text)
   end

   def decode_body(header_list, body_char_list) do
      Pop3mail.Handler.decode_body(header_list, body_char_list)
   end

   def decode_multipart(boundary_name, raw_content, path \\ '') do
      Pop3mail.Multipart.parse_multipart(boundary_name, raw_content, path)
   end

   def decode_raw_file(filename, output_dir) do
      unless File.dir?(output_dir), do: File.mkdir! output_dir
      case :file.read_file(filename) do
         {:ok, mail_content}  -> mail_content |> :erlang.binary_to_list |> Pop3mail.EpopDownloader.parse_process_and_store(1, nil, false, output_dir)
         {:error, :enoent}    -> IO.puts(:stderr, "File '" <> filename <> "' not found.")
         {:error, error_code} -> IO.puts(:stderr, "Error: #{error_code}")
      end
   end

end
