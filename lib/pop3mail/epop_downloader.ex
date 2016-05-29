
defmodule Pop3mail.EpopDownloader do
  alias Pop3mail.Handler

  require Logger

   defmodule Options do
      defstruct username: "", password: "", server: "", port: 995, ssl: true, max_mails: nil, delete: false, delivered: nil, save_raw: false, output_dir: ""
   end

   @doc "Read all emails and save them to disk."
   def download(options) do
     username = to_char_list(options.username)
     password = to_char_list(options.password)
     server = to_char_list(options.server)
     connect_options = [{:addr, server}, {:port, options.port}]
     if is_nil(options.ssl) or options.ssl do
       connect_options = connect_options ++ [:ssl]
     end
     case :epop_client.connect(username, password, connect_options) do
       {:ok,    client} -> retrieve_and_store_all(client, options)
       {:error, reason} -> Logger.error reason
     end
     Logger.info "Ready."
   end

   def retrieve_and_store_all(epop_client, options) do
     try do
        # This information returned by the server is not always reliable
        {:ok, {count, size_total}} = :epop_client.stat(epop_client)
        count_formatted = format_number(count)
        size_total_formatted = format_number(size_total)
        Logger.info "#{count_formatted} e-mails, #{size_total_formatted} bytes total."
        count = min(count, options.max_mails)
        if count > 0 do
            # create inbox directory to store emails
            unless File.dir?(options.output_dir), do: File.mkdir! options.output_dir
            # loop all messages
            1..count |> Enum.map(&retrieve_and_store(epop_client, &1, options))
        end
     after
        :epop_client.quit(epop_client)
     end
   end

   defp format_number(num) do
     # reverse digits, add a dot after every 3 places and reverse again
     num
     |> to_string
     |> String.reverse
     |> String.replace(~r/(\d{3})/, "\\1.")
     |> String.replace_suffix(".", "")
     |> String.reverse
   end 

   def retrieve_and_store(epop_client, mail_loop_counter, options) do
      case :epop_client.retrieve(epop_client, mail_loop_counter) do
        {:ok, mail_content} -> parse_process_and_store(mail_content, mail_loop_counter, options.delivered ,options.save_raw , options.output_dir)
                               if options.delete do
                                 :ok = :epop_client.delete(epop_client, mail_loop_counter)
                               end
        {:error, reason} -> Logger.error reason
      end
   end

   def parse_process_and_store(mail_content, mail_loop_counter, delivered, save_raw, output_dir) do
      {:message, header_list, body_char_list} = :epop_message.parse(mail_content)
      mail = %Handler.Mail{
        mail_content: mail_content,
        mail_loop_counter: mail_loop_counter,
        header_list: header_list,
        body_char_list: body_char_list
      }
      options = %Handler.Options{
        delivered: delivered,
        save_raw: save_raw,
        base_dir: output_dir
      }
      Handler.check_process_and_store(mail, options)
   end
    
end
