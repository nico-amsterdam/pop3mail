# Changelog

## v1.2.1 (2017-06-16)

* Bug fixes
  * Support RFC 2557 Content-Location header.

## v1.2.0 (2017-06-13)

* Bug fixes
  * [issue/2](https://github.com/nico-amsterdam/pop3mail/issues/2) Reduce memory consumption

## v1.1.0 (2017-02-01)

* Bug fixes
  * [issue/1](https://github.com/nico-amsterdam/pop3mail/issues/1) Pass on username unchanged to the mail server. In v1.0.0 it cuts off at the last @ symbol. Example: if username is hendrik.lorentz@gmail.com it logged in with user: hendrik.lorentz
