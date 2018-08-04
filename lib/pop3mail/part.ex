defmodule Pop3mail.Part do

   @moduledoc """
   A struct that holds a single part of a multipart, and if there isn't a multipart it contains the email body.

   It's fields are:
     * `content` - binary with the part's content.
     * `charset` - character encoding of the content (only applicable for text)
     * `media_type` - Mime type. Examples: text/plain, text/html, text/rtf, image/jpeg, application/octet-stream
     * `filename` - binary with filename of the attachment
     * `filename_charset` - character encoding of the filename
     * `inline` - true/false/nil. true=inline content, false=attachment, nil=not specified.
     * `path` - Path within the hierarchy of multipart's. For example: relative/alternative
     * `index` - Index number of a part within a multipart.
     * `boundary` - boundary name of the multipart
     * `content_id` - cid. Generally HTML refers to embedded objects (images mostly) by cid. That is why the related images have a cid.
     * `content_location` - URI location as defined in RFC 2557.
   """

   # a body part, or a single part of a multipart
   # content is binary, filename also
   @type t :: %Pop3mail.Part{index: integer, media_type: String.t, charset: String.t, path: String.t, filename: binary, filename_charset: String.t, boundary: String.t, content: binary, content_id: String.t, content_location: String.t, inline: boolean | nil}
   defstruct index: 0, media_type: "text/plain", charset: "us-ascii", path: "", filename: "", filename_charset: "us-ascii", boundary: "", content: "", content_id: "", content_location: "", inline: nil

end
