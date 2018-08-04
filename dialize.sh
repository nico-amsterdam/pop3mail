mix compile && dialyzer --verbose --no_check_plt -Werror_handling -Wrace_conditions -Wunderspecs -Wunknown -Wunmatched_returns -pa /usr/local/lib/elixir/lib/elixir/ebin ../erlpop/ebin -r _build/dev/lib/pop3mail/ebin
# dialyzer -pa /usr/local/lib/elixir/lib/elixir/ebin --build_plt --apps erts kernel stdlib httpd inet http_uri crypto ssl os ets -r /usr/local/lib/elixir/lib/elixir/ebin
#  dialyzer -pa /usr/local/lib/elixir/lib/elixir/ebin  --add_to_plt --apps
dialyzer -pa /usr/local/lib/elixir/lib/logger/ebin --add_to_plt --apps logger
