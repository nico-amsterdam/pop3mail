defmodule Pop3mailTest do
  use ExUnit.Case, async: true

  test "decode simple.eml" do

    expected = %Pop3mail.Part{boundary: "", charset: "iso-8859-1",
      content: "\r\nSorry, I am to busy.\r\nMaybe next time.\r\n\r\nBye\r\n\r\n",
      content_id: "", filename: "", filename_charset: "us-ascii", index: 1,
      inline: nil, media_type: "text/plain", path: ""}

      {:ok, content} = :file.read_file("test/pop3mail/fixtures/simple.eml")
      mail_content = :erlang.binary_to_list(content)
      {:message, header_list, body_char_list} = :epop_message.parse(mail_content)
      actual   = Pop3mail.decode_body_char_list(header_list, body_char_list)
      assert length(actual) == 1
      assert Enum.at(actual, 0) == expected
      
      content_type = Pop3mail.header_lookup(header_list, "Content-Type")
      encoding     = Pop3mail.header_lookup(header_list, "Content-Transfer-Encoding")
      assert content_type == "text/plain;charset=iso-8859-1"
      assert encoding == "8bit"

      body_text = :erlang.list_to_binary body_char_list
      actual2  = Pop3mail.decode_body(body_text, content_type, encoding, "")
      assert length(actual2) == 1
      assert Enum.at(actual2, 0) == expected

  end

end
