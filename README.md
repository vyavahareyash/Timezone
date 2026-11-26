# Timezone

A macOS menu bar app for converting one moment across several time zones at a glance — built for picking meeting times.

Click the menu bar icon and a panel opens: today's 24-hour Timeline for your Home zone, with every Zone you've added laid out below as aligned hour strips, shaded by working hours. Drag the Cursor to any time and every Zone shows its local time, day offset (+1/−1) and zone abbreviation.

## Status

Planning done, implementation not started. See the [v1 spec (#1)](https://github.com/vyavahareyash/Timezone/issues/1) and its sub-issues for the build plan.

## Docs

- [GLOSSARY.md](GLOSSARY.md): the project's vocabulary (Zone, Home zone, Timeline, Cursor, …)
- [docs/adr/](docs/adr/): architecture decisions
- [AGENTS.md](AGENTS.md): setup for coding agents

## Requirements

- The current macOS release and Xcode
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

Build instructions will be added with the first implementation ticket.

## Credits

City search uses data from [GeoNames](https://www.geonames.org/) (CC BY 4.0).
