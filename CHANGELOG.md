# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## v0.7.0 - 2019-04-22
* Updated Readme
* Updated Dependencies
* Ran Formatter
* Fixed warnings up to 1.8
* Support nested param filtering

## v0.6.0 - 2017-12-26
* Extra configuration that allows control of logging debug fields.
* Allow built-in logging keys to be suppressed
* Add Elixir 1.5.3 official support
* Add Erlang/OTP 20.1 official support
* Update dev & test dependencies

## v0.5.0 - 2017-08-21
* Extra attributes configuration that allows for logging custom metrics
* Add Elixir 1.5.1
* Add Erlang/OTP 20
* Add Erlang/OTP 19.3 to test suite

## v0.4.0 - 2017-03-18
* Breaking Changes!
* Log errors with logger level `error` instead of `info`
* Change `status` field to an integer type instead of string
* Drop official support of Elixir 1.2 and OTP 18
* Add support for Elixir 1.4 and OTP 19.1 & 19.2
* Update dependencies
* Fix dialyzer warnings

## v0.3.1 - 2017-01-05
* Update dependencies
* Fix Elixir 1.4 warnings

## v0.3.0 - 2016-11-22
* Breaking Changes!
* Drop the `fastly_duration` log value
* Add the ability to change verbosity. Log levels warn/debug will return everything from 0.2 minus fastly_duration. Log levels info/error will return a subset of warn/debug that is missing params, client_ip, & client_version.

## v0.2.0 - 2016-10-26
* Add support for error logging tagged with the request id. Errors now are bunched up as a single JSON message in addition to the standard output for easier parsing of errors and matching requests to the resulting error.
