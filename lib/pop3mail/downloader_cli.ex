defmodule Pop3mail.DownloaderCLI do
  alias Pop3mail.EpopDownloader

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
   defp show_error([]), do: IO.puts(:stderr, "Type 'backup_pop3_mail.exs --help' for more information.")

   # "print unknown options"
   defp show_error([{ option, _ } | tail]) do
      IO.puts(:stderr, "backup_pop3_mail.exs: Unknown option '" <> to_string(option) <> "'")
      show_error tail
   end

   # "print unknown arguments"
   defp show_error([arg | tail]) do
      IO.puts(:stderr, "backup_pop3_mail.exs: Unknown argument '" <> arg <> "'")
      show_error tail
   end

   # "print usage line"
   defp show_help do
     IO.puts "usage: backup_pop3_mail.exs [--username=[recent:]USERNAME] [--password=PASSWORD] [--max=INTEGER] [--delete] [--server=SERVER] [--port=INTEGER] [--ssl=false] [--delivered] [--raw] [--help]"
     IO.puts "This program wil read your gmail e-mails and save them including attachments on disk. See inbox directory."
   end


end
