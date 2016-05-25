defmodule Pop3mail.DownloaderCLI do
  alias Pop3mail.EpopDownloader
   
   defp usage_text do
     """
     usage: pop3_email_downloader.sh [--username=[recent:]USERNAME]
            [--password=PASSWORD] [--max=INTEGER] [--delete] [--server=SERVER]
            [--port=INTEGER] [--ssl=false] [--delivered] [--raw] [--help]
     Read e-mails from the inbox and save them including attachments on disk 
     in the 'inbox' subdirectory.
     
     --delete     delete e-mail after downloading. Default: false
                  Notice that Gmail ignores the delete 
                  and instead uses the Gmail account settings.
     --delivered  true/false. Skip e-mails with/without Delivered-To header. 
                  If you moved an e-mail from your sent box to your inbox it 
                  will not have the Delivered-To header. Default: don't skip
     --help       show this information.
     --max        maximum number of e-mails to download. Default: unlimited 
     --password   e-mail account password.
     --port       pop3 server port. Default: 995
     --raw        also save the unprocessed mail in a file called 'raw.txt'.
                  Usefull feature for error diagnostics.
     --server     pop3 server address. Default: pop.gmail.com
     --ssl        true/false. Turn on/off Secure Socket Layer. Default: true
     --username   e-mail account name.  Gmail users can precede the name with 
                  'recent:' to get the last 30 days mail, even if it has 
                  already been downloaded elsewhere.
     """
   end

   @doc "Call main optionally with username and password. E.g. main([\"--username=a.b@gmail.com\", \"--password=secret\"])"
   def main(args) do
     {options, illegal_args, failed_options} = OptionParser.parse(args, strict: [
         password:  :string,
         username:  :string,
         server:    :string,
         port:      :integer,
         ssl:       :boolean,
         max:       :integer,
         help:      :boolean,
         delete:    :boolean,
         delivered: :boolean,
         raw:       :boolean ])
     if options[:help] do
        show_help
     else
        process_options(options, illegal_args, failed_options)
     end
   end

   defp process_options(options,[],[]) do
     username  = options[:username] || IO.gets("Please enter your gmail account name: ") |> String.replace_suffix("\n", "")
     password  = options[:password] || IO.gets("Please enter your password: ") |> String.replace_suffix("\n", "")
     max_mails = options[:max]
     ssl       = options[:ssl]
     delete    = options[:delete]
     save_raw  = options[:raw]
     server    = options[:server] || "pop.gmail.com"
     port      = options[:port] || 995
     delivered = options[:delivered]
     EpopDownloader.download(username, password, server, port, ssl, max_mails, delete, delivered, save_raw, "inbox")
   end

   defp process_options(_,illegal_args,failed_options) do
     show_error(illegal_args ++ failed_options)
   end

   # "print last line of unknown options"
   defp show_error([]), do: IO.puts(:stderr, "Type 'pop3_email_downloader.sh --help' for more information.")

   # "print unknown options"
   defp show_error([{ option, _ } | tail]) do
      IO.puts(:stderr, "pop3_email_downloader.sh: Unknown option '" <> to_string(option) <> "'")
      show_error tail
   end

   # "print unknown arguments"
   defp show_error([arg | tail]) do
      IO.puts(:stderr, "pop3_email_downloader.sh: Unknown argument '" <> arg <> "'")
      show_error tail
   end

   # "print usage line"
   defp show_help do
     IO.puts usage_text
   end


end
