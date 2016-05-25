defmodule Pop3mail.DateConverter do

   def zero_pad(number, len \\ 2) do
     String.rjust(to_string(number), len, ?0)
   end

   def convert_date(date_str) do
          # Example of correctly formatted date: Tue, 14 Oct 2014 19:59:31 +0200
          # Sometimes the day of the week is missing in the date. Fix that:
          # if date starts with digit
          if date_str =~ ~r/^\s?\d/ do
             # Add the day first. We don't care which day it is, just add ???
             date_str = "???, " <> date_str
          end
          # httpd_util requires that single digit days have a leading zero. This is not always the case.
          day_and_date = String.slice(date_str, 5..-1) |> String.lstrip
          if day_and_date =~ ~r/^\d\s/ do
            # add leading zero
            date_str = String.slice(date_str, 0..4) <> "0" <> day_and_date
          end
          date_char_list = to_char_list(date_str)
          {{year, month, day}, {hour, minutes, seconds}} = :httpd_util.convert_request_date(date_char_list)
          zero_pad(year, 4) <> zero_pad(month) <> zero_pad(day) <> "_" <> zero_pad(hour) <> zero_pad(minutes) <> zero_pad(seconds)
   end

end
