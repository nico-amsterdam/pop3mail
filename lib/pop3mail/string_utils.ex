defmodule Pop3mail.StringUtils do

   @moduledoc "String manipulation utilities."

   @doc "Strip double quotes. Only when they occur at the start and end if the text. Strip balanced. Once only."
   def unquoted(text) do
      # strip quotes balanced
      remove_balanced(text, "\"")
   end

   @doc "Strip a character. Only when it occurs both at the start and end if the text. Strip once only."
   def remove_balanced(text, remove) do
      # strip balanced
      if String.starts_with?(text, remove) and String.ends_with?(text, remove) do
         text 
         |> String.replace_suffix(remove, "") 
         |> String.replace_prefix(remove, "")
      else
         text
      end
   end

   @doc "Print text if it valid utf-8 encoded. If not, print the alternative text."
   def printable(str, printable_alternative \\ "") do
      case String.printable?(str) do
        true  -> str
        false -> printable_alternative
      end
   end

   @doc "test if string is nil or has empty length"
   def is_empty?(str), do: is_nil(str) or String.length(str) == 0

   @doc "true if search is found in content"
   def contains?(content, search), do: !is_nil(content) and String.contains?(content, search)

end
