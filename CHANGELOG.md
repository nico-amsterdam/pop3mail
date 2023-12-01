# Changelog

## v1.5.0 (2023-12-01)
* Fixes
  * Verify server certificate in OTP 25 or higher
  * Fix connection_failed in OTP 26; use upgraded pop3client v1.4
  * New cli parameters: cacertfile and verify true/false
  * No warning anymore for Content-Length headers in multipart data

## v1.4.1 (2023-10-11)
* Bug fixes
  * Option --delivered crashes when logging warning about mail without Delivered-To header
  * Drop support for Elixir < 1.11. Logger.warning was introduced in 1.11.0

## v1.4.0 (2023-10-10)

* Bug fixes
  * Drop support for Elixir < 1.9
  * Fix Elixir 1.15 warnings: 
    * use Mix.Config -> import Config. Requires minimal Elixir 1.9
    * logger format in config.ex
    * Logger doesn't accept atoms anymore, to_string
    * Application.get_env -> compile_env
    * replace :http_uri.decode with URI.decode
    * Logger.warn -> Logger.warning
  * Fix Credo warnings: combine Enum.map and Enum.join as Enum.map_join
  * Fix Dialyzer warnings: Erlang returns error reason as atom (not a binary) 

## v1.3.4 (2020-10-07)

* Bug fixes
  * Fix Elixir 1.11 warnings; add application dependencies :pop3client and :inets

## v1.3.3 (2020-09-26)

* Bug fixes
  * Graceful error correction of common line continuation faults in Content-Description headers
  * Allow longer attachment filenames to be stored. Cut off at 100 characters.
  * Fix dialyzer warnings

## v1.3.2 (2019-05-24)

* Bug fixes
  * [issue/4](https://github.com/nico-amsterdam/pop3mail/issues/4) Mix compile with pop3mail dependency fails on erlpop.app

## v1.3.1 (2018-11-08)

* Bug fixes
  * [issue/3](https://github.com/nico-amsterdam/pop3mail/issues/3) Lookup headers case-insensitively

## v1.3.0 (2017-11-17)

* Drop support for Elixir 1.2
  * Minimal Elixir 1.3
  * Resolve deprecated warings in Elixir 1.5

## v1.2.1 (2017-06-16)

* Bug fixes
  * Support RFC 2557 Content-Location header.

## v1.2.0 (2017-06-13)

* Bug fixes
  * [issue/2](https://github.com/nico-amsterdam/pop3mail/issues/2) Reduce memory consumption

## v1.1.0 (2017-02-01)

* Bug fixes
  * [issue/1](https://github.com/nico-amsterdam/pop3mail/issues/1) Pass on username unchanged to the mail server. In v1.0.0 it cuts off at the last @ symbol. Example: if username is hendrik.lorentz@gmail.com it logged in with user: hendrik.lorentz
