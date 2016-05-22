# Pop3mail

    Pop3 client to download email (including attachments) from the inbox via the commandline or Elixir API.
    Written in Elixir, using an Erlang pop3 client with SSL support derived from the epop package.
    Decodes multipart content, quoted-printables, base64 and encoded-words.

## Before you start

- This program reads from a POP3 mail server, which means that it can only download mail from the inbox folder. If you want to access other folders you will need an IMAP client.
- Gmail users: whether the read mail is permanently deleted or not, depends on your gmail settings, and not on the delete parameter of this program. 
- Do NOT run the script as root.
- Downloaded attachments can contain viruses, addware or malicious scripts.

## Installation from scratch

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

For usage, see usage chapter below.

## Install in an Elixir project

[available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add pop3mail to your list of dependencies in `mix.exs`:

        def deps do
          [{:pop3mail, "~> 0.1.0"}, 
           {:erlpop, github: "trifork/erlpop"}]
        end

  2. Ensure pop3mail is started before your application:

        def application do
          [applications: [:pop3mail]]
        end

## Usage

### Commandline script

The script downloads email and writes the content in the inbox folder.
 
```sh
$ chmod +x pop3_email_downloader.sh
$ ./pop3_email_downloader.sh --help
$ ./pop3_email_downloader.sh --username=<your gmail username> --password=<your gmail password> --max=10 --raw
```

or without shell script:

```sh
$ mix run -e 'Pop3mail.DownloaderCLI.main(["--help"])'
$ mix run -e 'Pop3mail.DownloaderCLI.main(["--username=<user gmail username>", "--password=<your gmail password>", "--max=10", "--raw"])'
```

The script defaults to gmail, but you can specify other host and port names.

## Use in Elixir

Example:

```sh
$ iex -S mix

# notice that you must use single quotes here
iex(1)> {:ok, client} = :epop_client.connect('user@gmail.com', 'password', [{:addr, 'pop.gmail.com'},{:port,995},:ssl])
iex(2)> :epop_client.stat(client) 
iex(3)> {:ok, mail_content} = :epop_client.retrieve(client, 1) 
iex(4)> {:message, header_list, body_char_list } = :epop_message.parse(mail_content)
iex(5)> Pop3mail.header_lookup(header_list, "Subject")
iex(6)> Pop3mail.header_lookup(header_list, "From")
iex(7)> Pop3mail.header_lookup(header_list, "Date")
iex(8)> part_list = Pop3mail.decode_body(header_list, body_char_list)
iex(9)> Enum.at(part_list, 0).charset 
iex(10)> Enum.at(part_list, 0).content 
iex(11)> {:ok, mail_content} = :epop_client.retrieve(client, 2) 
iex(12)> {:message, header_list, body_char_list } = :epop_message.parse(mail_content)
iex(13)> Pop3mail.header_lookup(header_list, "Subject")
iex(14)> :epop_client.quit(client)
```

## Reset Gmail

Gmail remembers which mails are already read. Fortunetely Gmail can be reset to re-read all emails.

Login in www.gmail.com.
In Gmail webmail Settings > Forwarding and POP/IMAP, select another option for POP,
like Download mail from now on. Save change. 
Go back to settings and select Download all mail, Save change.

Now your email client should download all mail again.

## Google unlock captcha

https://accounts.google.com/displayunlockcaptcha


## Acknowledgement

Thanks Erik Søe Sørensen for upgrading the Epop client to the latest Erlang version.
