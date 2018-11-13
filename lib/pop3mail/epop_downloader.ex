
defmodule Pop3mail.EpopDownloader do
  alias Pop3mail.Handler

  require Logger

   @moduledoc "Retrieve and parse POP3 mail via the Epop client."

   @typedoc "Epop client from erlpop"
   @type epop_client :: {:sk, any, any, any, any, any, any, boolean}

   defmodule Options do

      @moduledoc """
      A struct that holds pop3mail parameter options.

      It's fields are:
      * `delete`     - delete email after downloading. Default: false.
      * `delivered`  - true/false/nil. Skip emails with/without/whatever Delivered-To header.
      * `max_mails`  - maximum number of emails to download. nil = unlimited
      * `output_dir` - output directory.
      * `password`   - email account password.
      * `port`       - pop3 server port.
      * `save_raw`   - also save the unprocessed mail in a file called 'raw.eml'.
      * `server`     - pop3 server address.
      * `ssl`        - true/false. Turn on/off Secure Socket Layer.
      * `username`   - email account name.
      """

      @type t :: %Options{username: String.t, password: String.t, server: String.t, port: integer, ssl: boolean, max_mails: integer, delete: boolean, delivered: boolean, save_raw: boolean, output_dir: String.t}
      defstruct username: "", password: "", server: "", port: 995, ssl: true, max_mails: nil, delete: false, delivered: nil, save_raw: false, output_dir: ""
   end

   @doc """
   Read all emails and save them to disk.

   `options` - EpopDownloader.Options
   """
   @spec download(Options.t) :: {:ok, integer} | {:error, String.t}
   def download(options) do
     username = to_charlist(options.username)
     password = to_charlist(options.password)
     server = to_charlist(options.server)
     connect_options = [{:addr, server}, {:port, options.port}, {:user, username}]
     connect_options =
       case is_nil(options.ssl) or options.ssl do
         true  -> connect_options ++ [:ssl]
         false -> connect_options
       end
     case :epop_client.connect(ensure_at_symbol(username, server), password, connect_options) do
       {:ok,    client} -> retrieve_and_store_all(client, options)
       {:error, reason} -> Logger.error(reason)
                           {:error, reason}
     end
   end

   # if username does not contain the @ symbol, add it. Both parameters must be char-lists.
   defp ensure_at_symbol(username, server) do
     case :string.chr(username, ?@) > 0 do
       true  -> username
       false -> username ++ '@' ++ server
     end
   end

   @doc """
   Read all emails and save them to disk.

   * `epop_client` - client returned by :epop_client.connect function.
   * `options` - EpopDownloader.Options
   """
   @spec retrieve_and_store_all(epop_client, Options.t) :: {:ok, integer}
   def retrieve_and_store_all(epop_client, options) do
        # This information returned by the server is not always reliable
        {:ok, {total_count, size_total}} = :epop_client.stat(epop_client)
        count_formatted = format_number(total_count)
        size_total_formatted = format_number(size_total)
        Logger.info "#{count_formatted} emails, #{size_total_formatted} bytes total."
        count = min(total_count, options.max_mails)
        _ = if count > 0 do
            # create inbox directory to store emails
            unless File.dir?(options.output_dir), do: File.mkdir! options.output_dir
            # loop all messages
            _ = 1..count |> Enum.map(&retrieve_and_store(epop_client, &1, options))
        end
        _ = :epop_client.quit(epop_client)
        {:ok, total_count}
   end

   # add thousand separators to make the number human readable.
   defp format_number(num) do
     # reverse digits, add a dot after every 3 places and reverse again
     num
     |> to_string
     |> String.reverse
     |> String.replace(~r/(\d{3})/, "\\1.")
     |> String.replace_suffix(".", "")
     |> String.reverse
   end

   @doc """
   Retrieve, parse and store an email.

   * `epop_client` - client returned by :epop_client.connect function.
   * `mail_loop_counter` - number of the email in the current session.
   * `options` - EpopDownloader.Options
   """
   @spec retrieve_and_store(epop_client, integer, Options.t) :: {:ok, integer} | {:skip, list({:header, String.t, String.t})} | {atom, String.t} | {:error, String.t, String.t}
   def retrieve_and_store(epop_client, mail_loop_counter, options) do
      case :epop_client.bin_retrieve(epop_client, mail_loop_counter) do
        {:ok, mail_content} -> result = parse_process_and_store(mail_content, mail_loop_counter, options.delivered, options.save_raw , options.output_dir)
                               if options.delete do
                                 :ok = :epop_client.delete(epop_client, mail_loop_counter)
                               end
                               # It might be time now to clean things up:
                               # :erlang.garbage_collect()
                               result
        {:error, reason} -> Logger.error(reason)
                            {:error, reason}
      end
   end

   @doc """
   Parse headers, decode body and store everything.

   * `mail_content` - string with the complete raw email message.
   * `mail_loop_count` - number of the email in the current session.
   * `delivered` - true/false/nil. Presence, absence or don't care of the 'Delivered-To' email header.
   * `save_raw` - true/false. Save or don't save the raw email message.
   * `output_dir` - directory where all emails are stored.
   """
   @spec parse_process_and_store(String.t, integer, boolean | nil, boolean, String.t) :: {:skip, list({:header, String.t, String.t})} | {atom, String.t} | {:error, String.t, String.t}
   def parse_process_and_store(mail_content, mail_loop_counter, delivered, save_raw, output_dir) do
      options = %Handler.Options{
        delivered: delivered,
        save_raw: save_raw,
        base_dir: output_dir
      }
      parsed_result = epop_parse(mail_content)
      case parsed_result do
        {:message, header_list, body_content} -> process_and_store(mail_content, mail_loop_counter, header_list, body_content, options)
        {_, _} -> parsed_result
      end
   end

   # call epop parser and catch parse exceptions
   defp epop_parse(mail_content) do
      try do
        :epop_message.bin_parse(mail_content)
      rescue
        # parse error
        e in ErlangError -> {error, reason} = e.original
                            Logger.error("  #{error}: #{reason}")
                            {error, mail_content}
      end
   end

   # Decode body, store headers and body content.
   # `options` - Handler.Options
   defp process_and_store(mail_content, mail_loop_counter, header_list, body_content, options) do
      mail = %Handler.Mail{
        mail_content: mail_content,
        mail_loop_counter: mail_loop_counter,
        header_list: header_list,
        body_content: body_content
      }
      Handler.check_process_and_store(mail, options)
   end

end
