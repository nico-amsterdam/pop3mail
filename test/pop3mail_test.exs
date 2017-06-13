defmodule Pop3mailTest do
  use ExUnit.Case, async: true

  test "decode simple.eml" do

    expected = %Pop3mail.Part{boundary: "", charset: "iso-8859-1",
      content: "\r\nSorry, I am to busy.\r\nMaybe next time.\r\n\r\nBye\r\n\r\n",
      content_id: "", filename: "", filename_charset: "us-ascii", index: 1,
      inline: nil, media_type: "text/plain", path: ""}

    {:ok, mail_content} = :file.read_file("test/pop3mail/fixtures/simple.eml")
    {:message, header_list, body_content} = :epop_message.bin_parse(mail_content)

    # decode method 1
    actual1  = Pop3mail.decode_body_content(header_list, body_content)
    assert length(actual1) == 1
    assert Enum.at(actual1, 0) == expected

    # header lookup
    content_type = Pop3mail.header_lookup(header_list, "Content-Type")
    encoding     = Pop3mail.header_lookup(header_list, "Content-Transfer-Encoding")
    assert content_type == "text/plain;charset=iso-8859-1"
    assert encoding == "8bit"

    # decode method 2
    actual2  = Pop3mail.decode_body(body_content, content_type, encoding, "")
    assert length(actual2) == 1
    assert Enum.at(actual2, 0) == expected

  end

  test "decode encoded-word-in-from.eml" do

    # é in iso-8859-1 = 233 = E9
    content_enum1 = "No problem, the reception will be open until 19.30 tomorrow.\r\n\r\nT" <> <<233>> <> "l: 555\r\n\r\n \r\n\r\n"
    content_enum2 = "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=iso-8859-1\">\r\n<html><head><title>hoi</title></head>\r\n<body lang=FR link=blue vlink=purple>\r\n<div class=Section1>\r\n\r\n<p>\r\nNo problem, the reception will be open until 19.30 tomorrow.</p>\r\n\r\n</div>\r\n</body>\r\n</html>\r\n"
    content_enum3 = <<71, 73, 70, 56, 57, 97, 1, 0, 1, 0, 128, 0, 0, 0, 0, 0, 255, 255, 255, 33, 249, 4, 1, 0, 0, 0, 0, 44, 0, 0, 0, 0, 1, 0, 1, 0, 0, 2, 1, 68, 0, 59>>

    expected_enum1 = %Pop3mail.Part{boundary: "----=_NextPart_001_0005_01D0C782.71A8D3F0", charset: "iso-8859-1",
            content: content_enum1,
            content_id: "", filename: "", filename_charset: "us-ascii", index: 1, inline: nil, media_type: "text/plain", path: "related/alternative"}

    expected_enum2 = %Pop3mail.Part{boundary: "----=_NextPart_001_0005_01D0C782.71A8D3F0", charset: "iso-8859-1",
            content: content_enum2,
            content_id: "", filename: "", filename_charset: "us-ascii", index: 2, inline: nil, media_type: "text/html", path: "related/alternative"}

    expected_enum3 = %Pop3mail.Part{boundary: "----=_NextPart_000_0004_01D0C782.71A41900", charset: "us-ascii",
            content: content_enum3,
            content_id: "<image001.gif@01D0C782.711C2450>", filename: "image001.gif", filename_charset: "us-ascii", index: 2, inline: nil, media_type: "image/gif", path: "related"}


    {:ok, mail_content} = :file.read_file("test/pop3mail/fixtures/encoded-word-in-from.eml")
    {:message, header_list, body_content} = :epop_message.bin_parse(mail_content)

    # decode method 1
    actual1   = Pop3mail.decode_body_content(header_list, body_content)
    assert length(actual1) == 3
    assert Enum.at(actual1, 0) == expected_enum1
    assert Enum.at(actual1, 1) == expected_enum2
    assert Enum.at(actual1, 2) == expected_enum3

    # header lookup
    content_type = Pop3mail.header_lookup(header_list, "Content-Type")
    encoding     = Pop3mail.header_lookup(header_list, "Content-Transfer-Encoding")
    assert content_type == "multipart/related; boundary=\"----=_NextPart_000_0004_01D0C782.71A41900\""
    assert encoding == ""

    # decode method 2
    actual2  = Pop3mail.decode_body(body_content, content_type, encoding, "")
    assert length(actual2) == 3
    assert Enum.at(actual2, 0) == expected_enum1
    assert Enum.at(actual2, 1) == expected_enum2
    assert Enum.at(actual2, 2) == expected_enum3

  end

  test "decode encoded-word-in-filename.eml" do

    expected = %Pop3mail.Part{
                boundary: "138975160-29007-1446582386=:3552",
                charset: "us-ascii",
                content: "Qu'vatlh uses the Klingon Q; you should pronounce this sound as in petaQ.",
                content_id: "", filename: "Invoice269082204400.pdf",
                filename_charset: "ISO-8859-15", index: 1, inline: false,
                media_type: "application/octet-stream", path: "mixed"}

    {:ok, mail_content} = :file.read_file("test/pop3mail/fixtures/encoded-word-in-filename.eml")
    {:message, header_list, body_content} = :epop_message.bin_parse(mail_content)
    actual    = Pop3mail.decode_body_content(header_list, body_content)

    assert length(actual) == 1
    assert actual == [expected]
  end

end
