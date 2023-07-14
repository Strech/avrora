# Changelog

## [0.27.0] - 2023-07-14 <sup>([notes][0.27.0-n])</sup>

- Replace `Logger.warn/1` with `Logger.warning/2` (#107 @trbngr, @strech)
- Drop support for Elixir lower than 1.12 (#107 @strech)

## [0.26.0] - 2023-01-11 <sup>([notes][0.26.0-n])</sup>

- Add `--appconfig` argument to schema registration mix task (#102 @emilianobovetti, @strech)

## [0.25.0] - 2023-01-03 <sup>([notes][0.25.0-n])</sup>

- Add User-Agent header when communicating with Schema Registry (#100 @azeemchauhan, @strech)

## [0.24.2] - 2022-09-13 <sup>([notes][0.24.2-n])</sup>

- Fix Avrora.Config.registry_schemas_autoreg/0 to return configured `false` value (#99 @ankhers)

## [0.24.1] - 2022-09-12 <sup>([notes][0.24.1-n])</sup>

- Add SSL option `[verify: :verify_none]` to Avrora.HttpClient (#97, @goozzik)

## [0.24.0] - 2022-03-16 <sup>([notes][0.24.0-n])</sup>

- Add new Avrora.Config option decoder_hook (#94, @strech)

## [0.23.0] - 2021-07-06 <sup>([notes][0.23.0-n])</sup>

- Add runtime config resolution for Avrora.Client (#92, @strech)

[0.27.0]: https://github.com/Strech/avrora/compare/v0.26.0...v0.27.0
[0.27.0-n]: https://github.com/Strech/avrora/releases/tag/v0.27.0
[0.26.0]: https://github.com/Strech/avrora/compare/v0.25.0...v0.26.0
[0.26.0-n]: https://github.com/Strech/avrora/releases/tag/v0.26.0
[0.25.0]: https://github.com/Strech/avrora/compare/v0.24.2...v0.25.0
[0.25.0-n]: https://github.com/Strech/avrora/releases/tag/v0.25.0
[0.24.2]: https://github.com/Strech/avrora/compare/v0.24.1...v0.24.2
[0.24.2-n]: https://github.com/Strech/avrora/releases/tag/v0.24.2
[0.24.1]: https://github.com/Strech/avrora/compare/v0.24.0...v0.24.1
[0.24.1-n]: https://github.com/Strech/avrora/releases/tag/v0.24.1
[0.24.0]: https://github.com/Strech/avrora/compare/v0.23.0...v0.24.0
[0.24.0-n]: https://github.com/Strech/avrora/releases/tag/v0.24.0
[0.23.0]: https://github.com/Strech/avrora/compare/v0.22.0...v0.23.0
[0.23.0-n]: https://github.com/Strech/avrora/releases/tag/v0.23.0
