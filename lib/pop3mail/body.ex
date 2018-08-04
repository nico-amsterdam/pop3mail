defmodule Pop3mail.Body do
  alias Pop3mail.FileStore
  alias Pop3mail.Part
  alias Pop3mail.Multipart
  alias Pop3mail.StringUtils

  require Logger

   @moduledoc "Decode and store mail body"

   @doc "Decode multipart content, base64, quoted-printables"
   @spec decode_body(String.t, String.t, String.t, String.t) :: list(Part.t)
   def decode_body(body_text, content_type, encoding, disposition) do
      decoded_binary = Multipart.decode(encoding, body_text)

      # pretend that the mail body is a multipart part, so it can be handled by the same code that handles multipart content
      mail_body_part = %Part{index: 1, content: decoded_binary}
         |> Multipart.parse_content_type(content_type) # extract from content_type the media_type, charset, boundary and put them in the mail_body_part
         |> Multipart.parse_disposition(disposition)   # disposition may contain filename

      # get multipart parts. Multipart will check if it is really a multipart, otherwise you get this part back.
      Multipart.parse_content(mail_body_part)
   end

   @doc "Store all found body parts on filesystem"
   @spec store_multiparts(list(Part.t), String.t) :: list({:ok, String.t} | {:error, String.t, String.t})
   def store_multiparts(multipart_part_list, dirname) do
      Enum.map(multipart_part_list, &(store_part(&1, dirname)))
   end

   @doc "Store one part on filesystem"
   @spec store_part(Part.t, String.t) :: {:ok, String.t} | {:error, String.t, String.t} 
   def store_part(multipart_part, base_dir) do
      # make sure we have a filename
      multipart_part =
        case String.length(multipart_part.filename) == 0 do
          # currently there is no filename, set default
          true  -> FileStore.set_default_filename(multipart_part)
          false -> multipart_part
        end
      Logger.info "    " <> StringUtils.printable(multipart_part.filename, "file")

      result = FileStore.store_part(multipart_part, base_dir)
      case result do
        {:ok, _} -> result
        {:error, reason, _} -> Logger.error(reason)
                               result
      end
   end

end
