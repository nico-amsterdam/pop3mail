# Pop3mail

    Pop3 client to download email (including attachments) from the inbox via the commandline or Elixir API.
    Written in Elixir, using an Erlang pop3 client with SSL support derived from the epop package.
    Decodes multipart content, quoted-printables, base64 and encoded-words.

## Before you start

- This program reads from a POP3 mail server, which means that it can only download mail from the inbox folder. If you want to access other folders you will need an IMAP client.
- Do NOT run the script as root.
- Downloaded attachments can contain viruses, addware or malicious scripts.
- This program does NOT convert charsets and neither does it add a [BOM](https://en.wikipedia.org/wiki/Byte_order_mark). 
  If a message is send in ISO-8859-1, CP1251, KOI8-R it wil be stored as such.
  Sometimes you must change the locale/charset/encoding (LC_CTYPE luit, chcp) in your terminal/device/program to be able to read the content.
  Elixir programmers can use [codepagex](https://github.com/tallakt/codepagex) to perform conversions to utf-8.

Gmail users:
- Whether the read mail is permanently deleted or not, depends on your Gmail settings, and not on the delete parameter of this program. 
- Gmail returns chunks of maximum 250-350 emails. Repeatedly run this program to get all emails.


## Installation from scratch

### Install Elixir

Follow the instructions on http://elixir-lang.org/install.html

Also install [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) and optionally also rebar3.


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

[available in Hex](https://hex.pm/packages/pop3mail), add pop3mail and the erlang epop client to your list of dependencies in `mix.exs`:

        def deps do
          [{:pop3mail, "~> 0.1.5"}, 
           {:erlpop, github: "trifork/erlpop"}]
        end

## Usage

### Commandline script

The script downloads email and writes the content in the inbox folder.
 
```sh
$ pop3mail_downloader --help
$ pop3mail_downloader --username=<your email username> --password=<your email password> --max=10 --raw
```

or without shell/batch script:

\*nix
```sh
$ mix run -e 'Pop3mail.CLI.main(["--help"])'
$ mix run -e 'Pop3mail.CLI.main(["--username=<user email username>", "--password=<your email password>", "--max=10", "--raw"])'
```

Windows
```dos
C:\pop3mail\mix run -e "Pop3mail.CLI.main([""--help""])"
C:\pop3mail\mix run -e "Pop3mail.CLI.main([""--username=<user email username>"", ""--password=<your email password>"", ""--max=10"", ""--raw""])"
```

The script defaults to Gmail, but you can specify other POP3 server and port settings.

### Use in Elixir

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
iex(8)> part_list = Pop3mail.decode_body_char_list(header_list, body_char_list)
iex(9)> length(part_list)
iex(10)> part = Enum.at(part_list, 0)
iex(11)> part.media_type
iex(12)> part.filename
iex(13)> part.charset
iex(14)> part.content
iex(15)> :epop_client.delete(client, 1)
iex(16)> {:ok, mail_content} = :epop_client.retrieve(client, 2) 
iex(17)> {:message, header_list, body_char_list } = :epop_message.parse(mail_content)
iex(18)> Pop3mail.header_lookup(header_list, "Subject")
iex(19)> :epop_client.quit(client)
```

## Spam folder

You better turn off the spam folder of your email account if you don't want to miss any email with this program.
In Gmail you cannot turn it off, but you can create a filter for spam with the option 'Never send it to spam'.

## Reset Gmail

Gmail remembers which mails are already read. Fortunetely Gmail can be reset to re-read all emails.

Login in www.gmail.com.
In Gmail webmail Settings > Forwarding and POP/IMAP, select another option for POP,
like Download mail from now on. Save change. 
Go back to settings and select Download all mail, Save change.

Now your email client should download all mail again.

## Google unlock captcha

If you get an error 'web login required', push the 'Continue' button in the browser:

https://accounts.google.com/DisplayUnlockCaptcha


## License

MIT

## Acknowledgment

Thanks Erik Søe Sørensen for upgrading the Epop client to the latest Erlang version.
