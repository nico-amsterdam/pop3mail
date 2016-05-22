defmodule Pop3mail.Handler do
  alias Pop3mail.Body
  alias Pop3mail.DateConverter
  alias Pop3mail.FileStore
  alias Pop3mail.Header
  alias Pop3mail.WordDecoder
  alias Pop3mail.StringUtils


  require Logger

   def check_process_and_store(mail_content, mail_loop_counter, header_list, body_char_list, delivered, save_raw, base_dir) do
     # skip or not
      run = is_nil(delivered) or (delivered == (String.length(Header.lookup(header_list, "Delivered-To")) > 2))
      if run do
          process_and_store(mail_content, mail_loop_counter, header_list, body_char_list, save_raw, base_dir)
      else
          Logger.info "  Skipped mail #{mail_loop_counter}: delivered = #{delivered}"
      end
   end

   def process_and_store(mail_content, mail_loop_counter, header_list, body_char_list, save_raw, base_dir) do
      date    = Header.lookup(header_list, "Date")
      subject = Header.lookup(header_list, "Subject")
      from    = Header.lookup(header_list, "From")
      date_dirname = convert_date_to_dirname(date)
      Logger.info "  Process mail #{mail_loop_counter}: #{date}"

      # create directory based on date received
      dirname = Path.join( base_dir , date_dirname <> "_" <> FileStore.remove_unwanted_chars(remove_encodings(subject), 22))
      unless File.dir?(dirname), do: File.mkdir! dirname 

      if save_raw do
         # for debugging
         case FileStore.store_raw(mail_content, dirname) do
              {:error, reason} -> Logger.error reason
              :ok -> ""
         end
      end

      filename_prefix = "header"
      # you get a sender name with removed encodings
      sender_name = get_sender_name(from)
      if String.length(sender_name) > 0 do
         filename_prefix = filename_prefix <> "_" <> FileStore.remove_unwanted_chars(sender_name, 35)
      end
      # store header info in a header file
      case Header.store(header_list, filename_prefix, dirname) do
           {:error, reason} -> Logger.error reason
           :ok -> ""
      end

      # body
      process_and_store_body(header_list, body_char_list, dirname)
   end


   def process_and_store_body(header_list, body_char_list, dirname) do

      multipart_part_list = decode_body(header_list, body_char_list)

      # store mail body, the multipart parts
      Body.store_multiparts(multipart_part_list, dirname)
   end

   # This is the main function
   def decode_body(header_list, body_char_list) do
      content_type = Header.lookup(header_list, "Content-Type")
      encoding = Header.lookup(header_list, "Content-Transfer-Encoding")
      # disposition in the header indicates inline or attachment. Can contain a filename
      disposition = Header.lookup(header_list, "Content-Disposition")

      body_binary = :erlang.list_to_binary(body_char_list)
      Body.decode_body(body_binary, content_type, encoding, disposition)
   end

   # date format must be conform RFC 2822
   # returns yyyymmdd_hhmmss
   def convert_date_to_dirname(date_str) do
        try do
          DateConverter.convert_date(date_str)
        rescue
          # :bad_date
          _ -> FileStore.remove_unwanted_chars(date_str, 26)
        end
   end

   def get_sender_name(from) do
     sender_name = from
     from_splitted = from |> String.split(~r/[<>]/)
     # if the format was:  name <email adres> you should have a array of 2
     if length(from_splitted) >= 2 do
        from_name = Enum.at(from_splitted, 0) |> String.strip |> StringUtils.unquoted
        if String.length(from_name) == 0 do
           # can only pick up the email between the < > brackets
           sender_name = Enum.at(from_splitted, 1) |> String.strip
        else
           sender_name = remove_encodings(sender_name)
        end
     end
     sender_name
   end

   # This function makes sure that the encoding markers are removed and the text decoded.
   # However, it does not convert to a standard encoding like utf-8 and it also doesn't mention the encoding types used.
   # What you get is a binary which you might be able to read depending on the character encoding set in your terminal/device/program.
   def remove_encodings(text) do
      decoded_text_list = WordDecoder.decode_text(text)
      Enum.map(decoded_text_list, fn({_, val}) -> val end) |> Enum.join
   end

end
