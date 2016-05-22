defmodule Pop3mail.Body do
  alias Pop3mail.FileStore
  alias Pop3mail.Part
  alias Pop3mail.Multipart

  require Logger

   def store_multiparts(multipart_part_list, dirname) do
      Enum.map(multipart_part_list, &(store_part(&1, dirname)))
   end
   
   def store_part(multipart_part, base_dir) do
      # make sure we have a filename
      if String.length(multipart_part.filename) == 0 do
         # currently there is no filename, set default
         multipart_part = FileStore.set_default_filename(multipart_part)
      end
      Logger.info "    " <> multipart_part.filename
      case FileStore.store_part(multipart_part, base_dir) do
           {:error, reason} -> Logger.error reason
           :ok -> ""
      end
   end

   def decode_body(body_text, content_type, encoding, disposition) do
      decoded_binary = Multipart.decode(encoding, body_text)

      # pretend that the mail body is a multipart part, so it can be handled by the same code that handles multipart content
      mail_body_part = %Part{ index: 1, content: decoded_binary }
         |> Multipart.parse_content_type(content_type) # extract from content_type the media_type, charset, boundary and put them in the mail_body_part
         |> Multipart.parse_disposition(disposition)   # disposition may contain filename

      # get multipart parts. Multipart will check if it is really a multipart, otherwise you get this part back.
      Multipart.parse_content(mail_body_part)
   end

end
