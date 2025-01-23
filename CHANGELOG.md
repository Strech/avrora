# Changelog

## [0.29.1] - 2025-01-22

- Fix regression caused by #129 (#136 @woylie)

## [0.29.0] - 2025-01-16

- Fix charlist warnings in Elixir 1.18 (#130 @sstoltze)
- Move private client otp_app check at compile-time (#129 @rockneurotiko)

## [0.28.0] - 2024-04-18

- Add new `Avrora.Config` SSL options `registry_ssl_cacerts` and `registry_ssl_cacert_path` (#114 @strech)

## [0.27.0] - 2023-07-14

- Replace `Logger.warn/1` with `Logger.warning/2` (#107 @trbngr, @strech)
- Drop support for Elixir lower than 1.12 (#107 @strech)

## [0.26.0] - 2023-01-11

- Add `--appconfig` argument to schema registration mix task (#102 @emilianobovetti, @strech)

## [0.25.0] - 2023-01-03

- Add `User-Agent` header when communicating with Schema Registry (#100 @azeemchauhan, @strech)

## [0.24.2] - 2022-09-13

- Fix `Avrora.Config.registry_schemas_autoreg/0` to return configured `false` value (#99 @ankhers)

## [0.24.1] - 2022-09-12

- Add SSL option `[verify: :verify_none]` to `Avrora.HttpClient` (#97, @goozzik)

## [0.24.0] - 2022-03-16

- Add new `Avrora.Config` option decoder_hook (#94, @strech)

## [0.23.0] - 2021-07-06

- Add runtime config resolution for Avrora.Client (#92, @strech)

[0.29.1]: https://github.com/Strech/avrora/releases/tag/v0.29.1
[0.29.0]: https://github.com/Strech/avrora/releases/tag/v0.29.0
[0.28.0]: https://github.com/Strech/avrora/releases/tag/v0.28.0
[0.27.0]: https://github.com/Strech/avrora/releases/tag/v0.27.0
[0.26.0]: https://github.com/Strech/avrora/releases/tag/v0.26.0
[0.25.0]: https://github.com/Strech/avrora/releases/tag/v0.25.0
[0.24.2]: https://github.com/Strech/avrora/releases/tag/v0.24.2
[0.24.1]: https://github.com/Strech/avrora/releases/tag/v0.24.1
[0.24.0]: https://github.com/Strech/avrora/releases/tag/v0.24.0
[0.23.0]: https://github.com/Strech/avrora/releases/tag/v0.23.0
