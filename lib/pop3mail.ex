defmodule Pop3mail do

   @moduledoc """
   Download email from the inbox and store them (including attachments) in a subdirectory per email.

   Reads incoming mail via the POP3 protocol, using an Erlang Epop client with SSL support.
   Decodes multipart content, quoted-printables, base64 and encoded-words.
   The module also contains functions to perform only the decoding,
   giving you the choice to do retrieval and storage with your own functions.
   """

   @doc ~S"""
   Commandline interface for downloading email and storing them on disk.

   ## Examples

     Download maximum 2 emails from the email account and also save the raw undecoded message.

       $ pop3mail_downloader --max=2 --raw --username=hendrik.lorentz@gmail.com --password=secret --output=mailbox

       or

       iex(1)> Pop3mail.cli(["--max=2", "--raw", "--username=hendrik.lorentz@gmail.com", "--password=secret", "--output=mailbox"])
       info:  297 emails, 57.643.477 bytes total.
       info:    Process mail 1: Mon, 13 Oct 2015 18:34:07 +0200
       info:      message1.txt
       info:      message2.html
       info:      Solution Skolem problem.docx
       info:    Process mail 2: Mon, 13 Oct 2015 19:38:14 +0200
       info:      message1.iso-8859-1.txt
       info:      message2.iso-8859-1.html
       {:ok, 297}

     Print the usage text. It has a long explanation of all the parameters.

       $ pop3mail_downloader --help

       or

       iex(1)> Pop3mail.cli(["--help"])
       usage: ...

   """
   @spec cli(list(String.t)) :: {:ok, integer} | {:error, String.t}
   def cli(args) do
      Pop3mail.CLI.main(args)
   end

   @doc ~S"""
   Download emails from the inbox and store them (including attachments) in a subdirectory per email.

   Parameters must be supplied in a string-keyed map:
   * `delete`    - delete email after downloading. Default: false. Notice that Gmail ignores the delete and instead uses the Gmail account settings.
   * `delivered` - true/false. Skip emails with/without Delivered-To header. If you moved an email from your sent box to your inbox it will not have the Delivered-To header. Default: don't skip
   * `max`       - maximum number of emails to download. Default: unlimited
   * `output`    - output directory. Default: inbox
   * `password`  - email account password.
   * `port`      - pop3 server port. Default: 995
   * `raw`       - also save the unprocessed mail in a file called 'raw.eml'. Usefull feature for error diagnostics.
   * `server`    - pop3 server address. Default: pop.gmail.com
   * `ssl`       - true/false. Turn on/off Secure Socket Layer. Default: true
   * `username`  - email account name. Gmail users can precede the name with 'recent:' to get the last 30 days mail, even if it has already been downloaded elsewhere.

   ## Example

     Download maximum 2 emails from the email account and also save the raw undecoded message.

       iex(1)> Pop3mail.download(%{"max" => 2, "raw" => true, "username" => "hendrik.lorentz@gmail.com", "password" => "secret", "output" => "mailbox"})

   """
   @spec download(keyword) :: {:ok, integer} | {:error, String.t}
   def download(params) do
     epop_options = %Pop3mail.EpopDownloader.Options{
       username:   params["username"],
       password:   params["password"],
       server:     params["server"] || "pop.gmail.com",
       port:       params["port"] || 995,
       ssl:        params["ssl"],
       max_mails:  params["max"],
       delete:     params["delete"],
       delivered:  params["delivered"],
       save_raw:   params["raw"],
       output_dir: params["output"] || "inbox"
     }
     Pop3mail.EpopDownloader.download(epop_options)
   end

   @doc ~S"""
   Lookup header in header list retrieved via epop.

   ## Example

     Retrieve email via epop_client and lookup headers 'Data', 'Subject' and 'From' and close the connection.

       iex(1)> # notice that you must use single quotes here
       iex(2)> {:ok, client} = :epop_client.connect('user@gmail.com', 'password', [{:addr, 'pop.gmail.com'},{:port,995},{:user, 'user@gmail.com'},:ssl])
       iex(3)> :epop_client.stat(client)
       iex(4)> {:ok, mail_content} = :epop_client.bin_retrieve(client, 1)
       iex(5)> {:message, header_list, body_content } = :epop_message.bin_parse(mail_content)
       iex(6)> Pop3mail.header_lookup(header_list, "Subject")
       "Solution Skolem problem"
       iex(7)> Pop3mail.header_lookup(header_list, "From")
       "Hendrik Lorentz <hendrik.lorentz@gmail.com>"
       iex(8)> Pop3mail.header_lookup(header_list, "Date")
       "Thu, 11 Jun 2015 18:05:26 +0000 (UTC)"
       iex(9)> :epop_client.quit(client)

   """
   @spec header_lookup(list({:header, String.t, String.t}), String.t) :: String.t
   def header_lookup(header_list, header_name) do
      Pop3mail.Header.lookup(header_list, header_name)
   end

   @doc ~S"""
   Decode a text with encoded words as defined in RFC 2047. Returns a list with tuples of charset name and binary content.

   Encoded words can occur in email headers (Subject, From, To) and for filenames in multipart content.

   ## Examples

     Russian subject

       iex> Pop3mail.decode_words("=?koi8-r?Q?Fwd:_=E4=CF=CD=C1=DB=CE=C5=C5_=DA=C1=C4=C1=CE=C9=C5_?=")
       [{"koi8-r",
             <<70, 119, 100, 58, 32, 228, 207, 205, 193, 219, 206, 197, 197, 32, 218, 193, 196, 193, 206, 201, 197, 32>>}]

     French (Réception) and ascii text email address

       iex(1)> Pop3mail.decode_words("=?iso-8859-1?Q?R=E9ception_Fayence?= <reception.fayence@acme.com>")
       [{"iso-8859-1",
             <<82, 233, 99, 101, 112, 116, 105, 111, 110, 32, 70, 97, 121, 101, 110, 99, 101>>},
            {"us-ascii", " <reception.fayence@acme.com>"}]

     Chinese

       iex(1)> Pop3mail.decode_words("chinese")
       [{"us-ascii", "chinese"}]

   """
   @spec decode_words(String.t) :: list({String.t, binary})
   def decode_words(text) do
      Pop3mail.WordDecoder.decode_text(text)
   end

   @doc ~S"""
   Decode multipart, base64 and quoted-printable text. Returned is a list of Pop3mail.Part structs.

   ## Example

     Retrieve email via epop_client and decode body and close the connection.

       iex(1)> # notice that you must use single quotes here
       iex(2)> {:ok, client} = :epop_client.connect('user@gmail.com', 'password', [{:addr, 'pop.gmail.com'},{:port,995},{:user, 'user@gmail.com'},:ssl])
       iex(3)> :epop_client.stat(client)
       iex(4)> {:ok, mail_content} = :epop_client.bin_retrieve(client, 1)
       iex(5)> {:message, header_list, body_content } = :epop_message.bin_parse(mail_content)
       iex(6)> Pop3mail.decode_body_content(header_list, body_content)
       [%Pop3mail.Part{boundary: "--_com.android.email_1191110031918720",
         charset: "utf-8",
         content: "\nPlease give me write access for the forum and possibly the wiki.\n\nTIA\n",
         content_id: "", filename: "", filename_charset: "us-ascii", index: 1,
         inline: nil, media_type: "text/plain", path: "alternative"},
        %Pop3mail.Part{boundary: "--_com.android.email_1191110031918720",
         charset: "utf-8",
         content: "<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\"></head><body ><div><br></div><div>Please give me write access for the forum and possibly the wiki.</div><div><br></div><div>TIA</div><div><br></div></body></html>",
         content_id: "", filename: "", filename_charset: "us-ascii", index: 2,
         inline: nil, media_type: "text/html", path: "alternative"}]
       iex(7)> :epop_client.quit(client)

   """
   @spec decode_body_content(list({:header, String.t, String.t}), String.t) :: list(Pop3mail.Part.t)
   def decode_body_content(header_list, body_content) do
      Pop3mail.Handler.decode_body_content(header_list, body_content)
   end

   @doc ~S'''
   Decode multipart, base64 and quoted-printable text. Returned is a list of Pop3mail.Part structs.

   ## Example

     Decode message with nested multipart content.

       iex(1)> message = """
       ...(1)> Il s'agit d'un message à parties multiples au format MIME.
       ...(1)>
       ...(1)> ------=_NextPart_000_0004_01D0C782.71A41900
       ...(1)> Content-Type: multipart/alternative;
       ...(1)> \tboundary="----=_NextPart_001_0005_01D0C782.71A8D3F0"
       ...(1)>
       ...(1)>
       ...(1)> ------=_NextPart_001_0005_01D0C782.71A8D3F0
       ...(1)> Content-Type: text/plain;
       ...(1)> \tcharset="iso-8859-1"
       ...(1)> Content-Transfer-Encoding: quoted-printable
       ...(1)>
       ...(1)> No problem, the reception will be open until 19.30 tomorrow.
       ...(1)>
       ...(1)> T=E9l: 555
       ...(1)>
       ...(1)> =20
       ...(1)>
       ...(1)>
       ...(1)> ------=_NextPart_001_0005_01D0C782.71A8D3F0
       ...(1)> Content-Type: text/html;
       ...(1)> \tcharset="iso-8859-1"
       ...(1)> Content-Transfer-Encoding: quoted-printable
       ...(1)>
       ...(1)> <META HTTP-EQUIV=3D"Content-Type" CONTENT=3D"text/html; =
       ...(1)> charset=3Diso-8859-1">
       ...(1)> <html><head><title>hoi</title></head>
       ...(1)> <body lang=3DFR link=3Dblue vlink=3Dpurple>
       ...(1)> <div class=3DSection1>
       ...(1)>
       ...(1)> <p>
       ...(1)> No problem, the reception will be open until 19.30 =
       ...(1)> tomorrow.</p>
       ...(1)>
       ...(1)> </div>
       ...(1)> </body>
       ...(1)> </html>
       ...(1)>
       ...(1)> ------=_NextPart_001_0005_01D0C782.71A8D3F0--
       ...(1)>
       ...(1)> ------=_NextPart_000_0004_01D0C782.71A41900
       ...(1)> Content-Type: image/gif;
       ...(1)> \tname="image001.gif"
       ...(1)> Content-Transfer-Encoding: base64
       ...(1)> Content-ID: <image001.gif@01D0C782.711C2450>
       ...(1)>
       ...(1)> R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7
       ...(1)>
       ...(1)> ------=_NextPart_000_0004_01D0C782.71A41900--
       ...(1)>
       ...(1)> """
       ...(2)> message |> String.replace("\n", "\r\n") |> Pop3mail.decode_body("multipart/related; boundary=\"----=_NextPart_000_0004_01D0C782.71A41900\"", "bit7", "")
       [%Pop3mail.Part{boundary: "----=_NextPart_001_0005_01D0C782.71A8D3F0",
         charset: "iso-8859-1",
         content: <<78, 111, 32, 112, 114, 111, 98, 108, 101, 109, 44, 32, 116, 104, 101, 32, 114, 101, 99, 101, 112, 116, 105, 111, 110, 32, 119, 105, 108, 108, 32, 98, 101, 32, 111, 112, 101, 110, 32, 117, 110, 116, 105, 108, 32, 49, ...>>,
         content_id: "", filename: "", filename_charset: "us-ascii", index: 1,
         inline: nil, media_type: "text/plain", path: "related/alternative"},
        %Pop3mail.Part{boundary: "----=_NextPart_001_0005_01D0C782.71A8D3F0",
         charset: "iso-8859-1",
         content: "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=iso-8859-1\">\r\n<html><head><title>hoi</title></head>\r\n<body lang=FR link=blue vlink=purple>\r\n<div class=Section1>\r\n\r\n<p>\r\nNo problem, the reception will be open until 19.30 tomorrow.</p>\r\n\r\n</div>\r\n</body>\r\n</html>\r\n",
         content_id: "", filename: "", filename_charset: "us-ascii", index: 2,
         inline: nil, media_type: "text/html", path: "related/alternative"},
        %Pop3mail.Part{boundary: "----=_NextPart_000_0004_01D0C782.71A41900",
         charset: "us-ascii",
         content: <<71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 128, 0, 0, 0, 0, 0, 255, 255, 255, 33, 249, 4, 1, 0, 0, 0, 0, 44, 0, 0, 0, 0, 1, 0, 1, 0, 0, 2, 1, 68, 0, 59>>,
         content_id: "<image001.gif@01D0C782.711C2450>", filename: "image001.gif",
         filename_charset: "us-ascii", index: 2, inline: nil, media_type: "image/gif",
         path: "related"}]

   '''
   @spec decode_body(String.t, String.t, String.t, String.t) :: list(Pop3mail.Part.t)
   def decode_body(body_text, content_type \\ "text/plain; charset=us-ascii", encoding \\ "7bit", disposition \\ "inline") do
     Pop3mail.Body.decode_body(body_text, content_type, encoding, disposition)
   end

   @doc ~S"""
   Decode raw message file (mostly an .eml file) and store result on disk.

   Returns a list with file storage results.

   ## Example

     Decode simple.eml and write result in the testoutput directory.

       iex(1)> Pop3mail.decode_raw_file("test/pop3mail/fixtures/simple.eml", "testoutput")
       info:    Process mail 1: Thu, 4 Sep 2014 19:23:15 +0200
       info:      message1.iso-8859-1.txt
       [ok: "testoutput/20140904_192315_Re_appointment/header.Marie.txt",
        ok: "testoutput/20140904_192315_Re_appointment/message1.iso-8859-1.txt"]

   """
   @spec decode_raw_file(String.t, String.t) :: {:error, String.t} | {String.t | atom, binary}
   def decode_raw_file(filename, output_dir) do
      unless File.dir?(output_dir), do: File.mkdir! output_dir
      case :file.read_file(filename) do
         {:ok, mail_content}  -> mail_content |> Pop3mail.EpopDownloader.parse_process_and_store(1, nil, false, output_dir)
         {:error, :enoent}    -> reason = "File '" <> filename <> "' not found."
                                 IO.puts(:stderr, reason)
                                 {:error, reason}
         {:error, error_code} -> reason = "Error: #{error_code}"
                                 IO.puts(:stderr, reason)
                                 {:error, reason}
      end
   end

end
