# Changelog

## Master
* Add Erlang/OTP 19.3 to test suite

## v0.4.0
* Breaking Changes!
* Log errors with logger level `error` instead of `info`
* Change `status` field to an integer type instead of string
* Drop official support of Elixir 1.2 and OTP 18
* Add support for Elixir 1.4 and OTP 19.1 & 19.2
* Update depedencies
* Fix dialyzer warnings

## v0.3.1
* Update depedencies
* Fix Elixir 1.4 warnings

## v0.3.0
* Breaking Changes!
* Drop the `fastly_duration` log value
* Add the ability to change verbosity. Log levels warn/debug will return everything from 0.2 minus fastly_duration. Log levels info/error will return a subset of warn/debug that is missing params, client_ip, & client_version.

## v0.2
* Add support for error logging tagged with the request id. Errors now are bunched up as a single JSON message in addition to the standard output for easier parsing of errors and matching requests to the resulting error.
