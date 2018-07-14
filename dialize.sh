mix compile && dialyzer --no_check_plt -Werror_handling -Wrace_conditions -Wunderspecs -Wunknown -Wunmatched_returns -pa /usr/local/lib/elixir/lib/elixir/ebin ../erlpop/ebin -r _build/dev/lib/pop3mail/ebin
# dialyzer -pa /usr/local/lib/elixir/lib/elixir/ebin ../erlpop/ebin -r _build/dev/lib/pop3mail/ebin
