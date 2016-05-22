# Pop3mail

    Pop3 client to download email (including attachments) from the inbox via the commandline or Elixir API.
    Written in Elixir, using an Erlang pop3 client with SSL support derived from the epop package.
    Decodes multipart content, quoted-printables, base64 and encoded-words.

## Before you start

- This program reads from a POP3 mail server, which means that it can only download mail from the inbox folder. If you want to access other folders you will need an IMAP client.
- Gmail users: whether the read mail is permanently deleted or not, depends on your gmail settings, and not on the delete parameter of this program. 
- Do NOT run the script as root.
- Downloaded attachments can contain viruses, addware or malicious scripts. Run a virus scanner.

## Installation

### Install Elixir

Follow the instructions on http://elixir-lang.org/install.html

### Clone project

```sh
$ git clone https://github.com/nico-amsterdam/pop3mail.git
```

### Compile & unit test

```sh
$ cd pop3mail
$ mix deps.get
$ mix test
```

A inbox directory will be created.
Modules in the lib directory will be converted to scripts in the script directory.
Assumed is that the modules all contain a main function.
The file 'mix.exs' contains the task to create the scripts during the compilation phase.
        
### Run the script

The script downloads email and writes the content in the inbox folder.
 
```sh
$ chmod +x pop3_email_downloader.sh
$ ./pop3_email_downloader.sh --help
$ ./pop3_email_downloader.sh --username=<your gmail username> --password=<your gmail password> --max=20 --raw
```

The script defaults to gmail, but you can specify other host and port names.

### Use in an Elixir project

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add pop3mail to your list of dependencies in `mix.exs`:

        def deps do
          [{:pop3mail, "~> 0.1.0"}]
        end

  2. Ensure pop3mail is started before your application:

        def application do
          [applications: [:pop3mail]]
        end

## Reset Gmail

Gmail remembers which mails are already read. Fortunetely Gmail can be reset to re-read all emails.

Login in www.gmail.com.
In Gmail webmail Settings > Forwarding and POP/IMAP, select another option for POP,
like Download mail from now on. Save change. 
Go back to settings and select Download all mail, Save change.

Now your email client should download all mail again.

