defmodule Pop3mail.CLITest do
   use ExUnit.Case, async: true

   import ExUnit.CaptureIO
   import Pop3mail.CLI, only: [main: 1]

   test "--help returns help output ignoring other parameters" do
      fun = fn -> main(["--username=a@b.c", "--password=secret", "--help"]) end
      expected = "usage: pop3"
      actual   = capture_io(:stdio, fun)
      assert String.starts_with?(actual, expected)
   end

end
