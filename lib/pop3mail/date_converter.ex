defmodule Pop3mail.DateConverter do

   @moduledoc "Date conversions and date utilities"

   @doc "add zero's at left side of the number"
   @spec zero_pad(non_neg_integer, non_neg_integer) :: String.t
   def zero_pad(natural_number, len \\ 2) when is_integer(natural_number) and natural_number >= 0 and is_integer(len) and len >= 0 do
     String.pad_leading(to_string(natural_number), len, ["0"])
   end

   @doc """
   Convert date from email header to a standard date format: YYYYMMDD_HHMMSS

   `datestr` - must be conform RFC 2822 date format
   """
   @spec convert_date(String.t) :: String.t
   def convert_date(date_str) do
     # Example of correctly formatted date: Tue, 14 Oct 2014 19:59:31 +0200
     # Sometimes the day of the week is missing in the date. Fix that:
     # if date starts with digit, add the day first. We don't care which day it is, just add ???
     date_str =
        if date_str =~ ~r/^\s?\d/ do
           "???, " <> date_str
        else
           date_str
        end
     # httpd_util requires that single digit days have a leading zero. This is not always the case.
     day_and_date = date_str
                    |> String.slice(5..-1//1)
                    |> String.trim_leading
     # add leading zero
     date_str =
       if day_and_date =~ ~r/^\d\s/ do
          String.slice(date_str, 0..4) <> "0" <> day_and_date
       else
          date_str
       end
     date_char_list = to_charlist(date_str)
     {{year, month, day}, {hour, minutes, seconds}} = :httpd_util.convert_request_date(date_char_list)
     zero_pad(year, 4) <> zero_pad(month) <> zero_pad(day) <> "_" <> zero_pad(hour) <> zero_pad(minutes) <> zero_pad(seconds)
   end

end
