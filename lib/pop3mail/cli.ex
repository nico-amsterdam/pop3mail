defmodule Pop3mail.CLI do
  alias Pop3mail.EpopDownloader

   @moduledoc "Commandline interface for downloading emails and storing them on disk."

   defp usage_text do
     """
     usage: pop3mail_downloader [--username=[recent:]USERNAME]
            [--password=PASSWORD] [--max=INTEGER] [--delete] [--server=SERVER]
            [--output=DIRECTORY] [--cacertfile=FILE] [--verify=false]
            [--port=INTEGER] [--ssl=false] [--delivered] [--raw] [--help]
     Read emails from the inbox and save them including attachments on disk
     in the 'inbox' subdirectory.

     --cacertfile full filename of the file with CA certificates to verify 
                  the mailserver. Default: use OS CA certificates
     --delete     delete email after downloading. Default: false
                  Notice that Gmail ignores the delete
                  and instead uses the Gmail account settings.
     --delivered  true/false. Skip emails with/without Delivered-To header.
                  If you moved an email from your sent box to your inbox it
                  will not have the Delivered-To header. Default: don't skip
     --help       show this information.
     --max        maximum number of emails to download. Default: unlimited
     --output     output directory. Default: inbox
     --password   email account password.
     --port       pop3 server port. Default: 995
     --raw        also save the unprocessed mail in a file called 'raw.eml'.
                  Useful feature for error diagnostics.
     --server     pop3 server address. Default: pop.gmail.com
     --ssl        true/false. Turn on/off Secure Socket Layer. Default: true
     --username   email account name.  Gmail users can precede the name with
                  'recent:' to get the last 30 days mail, even if it has
                  already been downloaded elsewhere.
     --verify     true/false. Turn on/off server certificate verification. 
                  Default: true
     """
   end

   @doc "Call main with parameters. E.g. main([\"--username=a.b@gmail.com\", \"--password=secret\"]). Call with --help to get a list of all parameters."
   @spec main(any()) :: {:ok, integer} | {:error, any}
   def main(args) when is_list(args) do
     {options, illegal_args, failed_options} = OptionParser.parse(args, strict: [
         password:   :string,
         username:   :string,
         server:     :string,
         cacertfile: :string,
         port:       :integer,
         ssl:        :boolean,
         verify:     :boolean,
         max:        :integer,
         delete:     :boolean,
         delivered:  :boolean,
         help:       :boolean,
         raw:        :boolean,
         output:     :string])
     if options[:help] do
        show_help()
     else
        process_options(options, illegal_args, failed_options)
     end
   end

   def main(_) do
     show_help()
   end

   # get user input. Used for username/password.
   defp ask(question) do
     answer = IO.gets(question)
     String.replace_suffix(answer, "\n", "")
   end

   # All parameters are parsed succesful, so take the options, apply defaults and call the download function.
   defp process_options(options, [], []) do
     username = options[:username] || ask("Please enter your email account name: ")
     password = options[:password] || ask("Please enter your password: ")
     epop_options = %EpopDownloader.Options{
       username:   username,
       password:   password,
       server:     options[:server] || "pop.gmail.com",
       port:       options[:port] || 995,
       ssl:        options[:ssl],
       verify:     options[:verify],
       cacertfile: options[:cacertfile],
       max_mails:  options[:max],
       delete:     options[:delete],
       delivered:  options[:delivered],
       save_raw:   options[:raw],
       output_dir: options[:output] || "inbox"
     }
     EpopDownloader.download(epop_options)
   end

   # there are incorrect commandline parameters
   defp process_options(_, illegal_args, failed_options) do
     all_errors = illegal_args ++ failed_options
     show_error(all_errors)
     {:error, all_errors}
   end

   # "print last line of unknown options"
   defp show_error([]), do: IO.puts(:stderr, "Type 'pop3mail_downloader --help' for more information.")

   # "print unknown option"
   defp show_error([{option, _} | tail]) do
      IO.puts(:stderr, "pop3mail_downloader: Unknown option '" <> to_string(option) <> "'")
      show_error tail
   end

   # "print unknown parameter"
   defp show_error([argument | tail]) do
      IO.puts(:stderr, "pop3mail_downloader: Unknown parameter '" <> argument <> "'")
      show_error tail
   end

   @doc "print usage line and a description for all parameters."
   @spec show_help() :: {:ok, 0}
   def show_help do
     IO.puts usage_text()
     {:ok, 0}
   end

end
