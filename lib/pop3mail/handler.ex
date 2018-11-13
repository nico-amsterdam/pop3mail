defmodule Pop3mail.Handler do
  alias Pop3mail.Body
  alias Pop3mail.DateConverter
  alias Pop3mail.FileStore
  alias Pop3mail.Header
  alias Pop3mail.WordDecoder
  alias Pop3mail.StringUtils

  require Logger

   @moduledoc "Glue code for received mail to call the parse, decode and store functions"

   defmodule Mail do

      @moduledoc """
      A struct that holds mail content.

      It's fields are:
        * `mail_content` - string with the complete raw email content
        * `mail_loop_counter` - Current number of the email in the retrieval loop. In an POP3 connection each email is numbered, starting at 1.
        * `header_list` - list with tuples of {:header, header name, header value}.
        * `body_content` - email body.
      """

      @type t :: %Mail{mail_content: String.t, mail_loop_counter: integer, header_list: list({:header, String.t, String.t}), body_content: String.t}
      defstruct mail_content: "", mail_loop_counter: 0, header_list: [], body_content: ""
   end

   defmodule Options do

      @moduledoc """
      A struct that holds options for the Pop3mail.Handler.

      It's fields are:
        * `delivered` - true/false/nil. Presence, absence or don't care of the 'Delivered-To' email header.
        * `save_raw` - true/false. Save or don't save the raw email message.
        * `base_dir` - directory where the emails must be stored.
      """

      @type t :: %Options{delivered: boolean | nil, save_raw: boolean, base_dir: String.t}
      defstruct delivered: nil, save_raw: false, base_dir: ""
   end


   @doc """
   Check if the mail must be skipped, if not process and store the email.

   It checks if the email has or hasn't got the Delivered-To header. Mail could be moved from the sent box to the inbox.

   `mail`    - Handler.Mail
   `options` - Handler.Options
   """
   @spec check_process_and_store(Mail.t, Options.t) :: list({:ok, String.t} | {:error, String.t, String.t}) | {:skip, list({:header, String.t, String.t})}
   def check_process_and_store(mail, options) do
     # skip or not. don't skip if delivered=nil or delivered is true/false and there is/isn't a Delivered-To header.
      run = is_nil(options.delivered) or (options.delivered == has_delivered_to_header(mail.header_list))
      if run do
          process_and_store(mail, options)
      else
          date = Header.lookup(mail.header_list, "Date")
          Logger.info "  Mail #{mail.mail_loop_counter} dated #{date} not stored because of delivered=#{mail.delivered} parameter."
          {:skip, mail.header_list}
      end
   end

   # Lookup the 'Delivered-To' header and look if it contains something (it should be an email address).
   defp has_delivered_to_header(header_list) do
      delivered_to = Header.lookup(header_list, "Delivered-To")
      String.length(delivered_to) > 2
   end

   @doc """
   Create directory for the email based on date and subject, save raw email, store header summary and store everything from the body.

   `mail`    - Handler.Mail
   `options` - Handler.Options
   """
   @spec process_and_store(Mail.t, Options.t) :: list({:ok, String.t} | {:error, String.t, String.t})
   def process_and_store(mail, options) do
      date    = Header.lookup(mail.header_list, "Date")
      subject = Header.lookup(mail.header_list, "Subject")
      from    = Header.lookup(mail.header_list, "From")
      date_dirname = convert_date_to_dirname(date)
      Logger.info "  Process mail #{mail.mail_loop_counter}: #{date}"

      # create directory based on date received
      dirname = FileStore.mkdir(options.base_dir, date_dirname, remove_encodings(subject))

      _ = if options.save_raw, do: save_raw(mail.mail_content, dirname)

      filename_prefix = "header"
      # you get a sender name with removed encodings
      sender_name = get_sender_name(from)

      # store header info in a header file
      header_result = store_header(mail.header_list, filename_prefix, sender_name, dirname)

      # body
      [header_result] ++ process_and_store_body(mail.header_list, mail.body_content, dirname)
   end

   # Store the header and log any errors.
   defp store_header(header_list, filename_prefix, sender_name, dirname) do
      result = Header.store(header_list, filename_prefix, sender_name, dirname)
      case result do
           {:ok, _} -> result
           {:error, reason, _} -> Logger.error(reason)
                                  result
      end
   end

   # Store the raw email content and log any errors.
   defp save_raw(mail_content, dirname) do
      # for debugging
      result = FileStore.store_raw(mail_content, "raw.eml", dirname)
      case result do
           {:ok, _} -> result
           {:error, reason, _} -> Logger.error(reason)
                                  result
      end
   end

   @doc """
   Decode and store body.

   `header_list` - list with tuples of {:header, header name, header value}.
   """
   @spec process_and_store_body(list({:header, String.t, String.t}), String.t, String.t) :: list({:ok, String.t} | {:error, String.t, String.t})
   def process_and_store_body(header_list, body_content, dirname) do
      multipart_part_list = decode_body_content(header_list, body_content)

      # store mail body, the multipart parts
      Body.store_multiparts(multipart_part_list, dirname)
   end

   @doc """
   Decode body: multipart content, base64 and quoted-printable.

   Returns a list of Pop3mail.Part's.

   `header_list` - list with tuples of {:header, header name, header value}.
   """
   @spec decode_body_content(list({:header, String.t, String.t}), String.t) :: list(Pop3mail.Part.t)
   def decode_body_content(header_list, body_content) do
      content_type = Header.lookup(header_list, "Content-Type")
      encoding = Header.lookup(header_list, "Content-Transfer-Encoding")
      # disposition in the header indicates inline or attachment. Can contain a filename
      disposition = Header.lookup(header_list, "Content-Disposition")

      Body.decode_body(body_content, content_type, encoding, disposition)
   end

   @doc """
   Convert date to a directory name meant for storing the email. Returned date is in format yyyymmdd_hhmmss

   `date_str` - string with the date. Must be conform RFC 2822 date format.
   """
   @spec convert_date_to_dirname(String.t) :: String.t
   def convert_date_to_dirname(date_str) do
      try do
        DateConverter.convert_date(date_str)
      rescue
        # :bad_date
        _ -> FileStore.remove_unwanted_chars(date_str, 26)
      end
   end

   @doc "Extract the sender name from the email 'From' header."
   @spec get_sender_name(String.t) :: String.t
   def get_sender_name(from) do
     from_splitted = String.split(from, ~r/[<>]/)
     # if the format was:  name <email adres> you should have a array of 2
     if length(from_splitted) >= 2 do
        from_name = from_splitted
                    |> Enum.at(0)
                    |> String.trim
                    |> StringUtils.unquoted
        if String.length(from_name) == 0 do
           # can only pick up the email between the < > brackets
           from_splitted
           |> Enum.at(1)
           |> String.trim
        else
           remove_encodings(from_name)
        end
     else
       from
     end
   end

   @doc """
   This function makes sure that the encoding markers are removed and the text decoded.

   However, it does not convert to a standard encoding like utf-8 and it also doesn't mention the encoding types used.
   What you get is a binary which you might be able to read depending on the character encoding set in your terminal/device/program.
   """
   @spec remove_encodings(String.t) :: String.t
   def remove_encodings(text) do
      decoded_text_list = WordDecoder.decode_text(text)
      decoded_text_list
      |> Enum.map(fn({_, val}) -> val end)
      |> Enum.join
   end

end
