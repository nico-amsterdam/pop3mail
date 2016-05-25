defmodule Pop3mail.StringUtils do

   # strip double quotes. Only when they occur at the start and end if the text. Strip balanced. Once only.
   def unquoted(text) do
      remove_balanced(text, "\"")
   end

   def remove_balanced(text, remove) do
      # strip quotes balanced
      if String.starts_with?(text, remove) and String.ends_with?(text, remove) do
         text = String.replace_suffix(text, remove, "") |> String.replace_prefix(remove, "")
      end
      text
   end

   def printable(str, printable_alternative \\ "") do
      if String.printable?(str) do
        str
      else
        printable_alternative
      end
   end

end
