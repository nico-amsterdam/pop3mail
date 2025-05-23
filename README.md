# Pop3mail [![Hex Version](https://img.shields.io/hexpm/v/pop3mail.svg)](https://hex.pm/packages/pop3mail) [![Inline docs](http://inch-ci.org/github/nico-amsterdam/pop3mail.svg)](http://inch-ci.org/github/nico-amsterdam/pop3mail)

    Pop3 client to download email (including attachments) from the inbox via the commandline or Elixir API.
    Written in Elixir, using an Erlang pop3 client with SSL support derived from the epop package.
    Decodes multipart content, quoted-printables, base64 and encoded-words.

## Implemented RFC's in Pop3mail to decode email

- [RFC 5322](https://tools.ietf.org/html/rfc5322) previously RFC 822 and RFC 2822
- [RFC 2045](https://tools.ietf.org/html/rfc2045)
- [RFC 2046](https://tools.ietf.org/html/rfc2046)
- [RFC 2047](https://tools.ietf.org/html/rfc2047)
- [RFC 2231](https://tools.ietf.org/html/rfc2231)
- [RFC 2557](https://tools.ietf.org/html/rfc2557)

## Before you start

- This program reads from a POP3 mail server, which means that it can only download mail from the inbox folder. If you want to access other folders you will need an IMAP client.
- Handling big attachments requires some processing memory. Normally the program needs about 30Mb RAM (for the whole OS process), but to process an email with attachments it temporary needs 3 times of the total size of the email attachments as additional memory.
- Elixir programmers can replace the default Pop3mail.Base64Decoder with their own.
- On linux when there is not enough memory, the program will end as 'Killed.'
  It's killed by the OOM Killer. Run dmesg to see the log message.
- On windows when there is not enough memory the program get stuck, or worse windows get stuck. 
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

### Erlang/OTP version

Use [this list](https://hexdocs.pm/elixir/compatibility-and-deprecations.html#compatibility-between-elixir-and-erlang-otp) for Elixir and OTP compatibility.

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

  1. Add pop3mail to your list of dependencies in `mix.exs`:
```
        def deps do
          [{:pop3mail, "~> 1.5"}]
        end
```

### Upgrade to 1.5

Pop3mail 1.5 uses pop3client 1.4

Use pop3client 1.4 for OTP 26 and higher. Pop3client 1.3 on OTP 26 results in a connection_failed error, because it doesn't provide
cacerts keys to the ssl connections, and OTP 26 has [safer ssl defaults](https://www.erlang.org/patches/otp-26.0#OTP-18455) to verify the server certificate. 

pop3client v1.4 by default verifies the server certificate on OTP 25 and 26. It's uses the cacerts keys from the OS via :public_key.cacerts_get/0

The pop3mail cli has a new cacertfile parameter to supply your own CA Certificates.

### Upgrade instructions 1.3.1 to 1.3.2

Run:
```elixir
mix deps.clean erlpop
mix deps.update pop3mail
```
After the `mix deps.clean erlpop` command, the `deps/erlpop` directory should be gone, and also the `_build/dev/lib/erlpop` and `_build/test/lib/erlpop` should be vanished.

### Upgrade instructions 1.3.0 to 1.3.1

Version 1.3.1 doesn't require erlpop as github dependency anymore, because it is now available in hex.pm as 'pop3client'
and added as dependency for pop3mail. Remove {:erlpop, github: "nico-amsterdam/erlpop"} in your mix.exs. 
If you don't mix reports: 'Dependencies have diverged'

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
$ mix run_pop3mail --help
$ mix run_pop3mail --username='<your email username>' --password='<your email password>' --max=10 --raw
```

Windows
```dos
C:\pop3mail\mix run_pop3mail --help
C:\pop3mail\mix run_pop3mail --username="<your email username>" --password="<your email password>" --max=10 --raw
```

The script defaults to Gmail, but you can specify other POP3 server and port settings.

### Use in Elixir

[Documentation is available online][docs]

Example:

```sh
$ iex -S mix

# notice that you must use the c-sigil ~c for character lists
iex(1)> {:ok, client} = :epop_client.connect(~c"user@gmail.com", ~c"password", 
...(1)>   [:ssl, {:addr, ~c"pop.gmail.com"}, {:port, 995}, {:user, ~c"user@gmail.com"}])
iex(2)> :epop_client.stat(client) 
iex(3)> {:ok, mail_content} = :epop_client.bin_retrieve(client, 1) 
iex(4)> {:message, header_list, body_content } = :epop_message.bin_parse(mail_content)
iex(5)> Pop3mail.header_lookup(header_list, "Subject")
iex(6)> Pop3mail.header_lookup(header_list, "From")
iex(7)> Pop3mail.header_lookup(header_list, "Date")
iex(8)> part_list = Pop3mail.decode_body_content(header_list, body_content)
iex(9)> length(part_list)
iex(10)> part = Enum.at(part_list, 0)
iex(11)> part.media_type
iex(12)> part.filename
iex(13)> part.charset
iex(14)> part.content
iex(15)> :epop_client.delete(client, 1)
iex(16)> {:ok, mail_content} = :epop_client.bin_retrieve(client, 2) 
iex(17)> {:message, header_list, body_content } = :epop_message.bin_parse(mail_content)
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

## Access Gmail with less secure apps

Google only trusts google apps. Gmail is trusted, but pop3mail not.
You will notice that authentication fails, and google will sent you a security warning by email.
Access with less secure apps can be turned on for your google account at: 
https://myaccount.google.com/lesssecureapps
2 step verification must be on: https://myaccount.google.com/signinoptions/two-step-verification
In the 2 step verification section, it is possible to set an app password: https://myaccount.google.com/apppasswords
Use the 16 character password.

More info: [Sign in with app passwords](https://support.google.com/accounts/answer/185833)


## License

[MIT](LICENSE)

## Acknowledgment

Thanks Erik Søe Sørensen for upgrading the Epop client to the OTP 15 Erlang version.

[docs]: https://hexdocs.pm/pop3mail/Pop3mail.html
