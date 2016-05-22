defmodule Pop3mail.Part do

   # a body part, or a single part of a multipart
   defstruct index: 0, media_type: "text/plain", charset: "us-ascii", path: "", filename: "", filename_charset: "us-ascii", boundary: "", content: "", content_id: "", inline: nil

end
