# Timezone

A macOS menu bar app for converting one moment across several time zones at a glance, built for picking meeting times.

Click the menu bar icon and a panel opens: today's Timeline for your Home zone, with every Zone you've added laid out below as aligned hour strips, shaded by working hours. Move the Cursor to any moment and every Zone shows its local time, its day offset (+1 or −1) and its zone abbreviation.

## Using it

The app lives only in the menu bar (there is no Dock icon). Click the globe icon to open the panel, and click outside it to close it.

### Reading the panel

- **Home zone** is your Mac's current time zone. It is always the first row, and its label comes from the system. It follows your Mac if you travel.
- **Timeline** is today, midnight to midnight, in your Home zone.
- **Strips** show each Zone's hours aligned to the same Timeline, so one vertical line is the same moment in every row. Hours are shaded by working hours: **yellow** for working hours (09:00–18:00 local), **light grey** for evening and **darker grey** for night. The numbers are each Zone's local hours, labelled every 3 hours, and the hour under the Cursor is bold.
- **Now** is the thin red line through every strip.
- **Day offset** (+1 or −1) appears next to a time when that Zone's date differs from your Home zone's date at the Cursor, so you don't propose a time that is tomorrow for someone.
- **Abbreviation** (e.g. CET or CEST) shows whether daylight saving time is in effect.

### Moving the Cursor

The Cursor is the vertical line with a handle at the top. It opens at Now and keeps tracking Now until you move it ("Following Now" in the header).

- Drag the handle to scrub through the day.
- Click or drag anywhere on a strip to jump the Cursor there.
- Click the handle, then press ← or → to move it 15 minutes at a time.
- Press **Back to Now** in the header to return to the present and resume following.

The Cursor snaps to 15-minute steps and stays within today. Reopening the panel puts it back at Now.

### Adding a Zone

1. Click the **+** button at the bottom of the panel.
2. Type a city. Search works offline and matches by name, ignoring accents, for example "Pune", "San Francisco" or "Zürich".
3. Click a result. The new Zone is labelled with the city name.

The city list comes from GeoNames (CC BY 4.0); its credit is shown under the search results.

### Managing Zones

- **Rename or remove:** right-click a Zone's row, then choose **Rename** or **Remove**. Rename opens an editable label; press Return or click away to save it.
- **Reorder:** drag a Zone's row up or down. The other Zones slide aside to show where it will land, and the row stops at the top and bottom of the list. The Home zone stays first.
- You can add the same time zone more than once under different labels, for example "Client" and "Sales".
- Your Zones are saved automatically and restored on the next launch.
- With more than about eight Zones, the list scrolls.

### The ⋯ menu

- **Launch at login:** starts Timezone when you log in. The first time you turn it on, macOS may ask you to allow it in System Settings > Login Items; the toggle opens that pane for you.
- **Quit:** closes the app.

### Limits

- The panel shows today only. You can't yet pick another date, so an upcoming daylight-saving change isn't visible until it is today.
- Times follow your macOS 12- or 24-hour setting.

## Install from source

There is no packaged download yet. Build the app from source:

1. Install the current macOS release and Xcode.
2. Install XcodeGen: `brew install xcodegen`
3. Clone this repository and run:

   ```sh
   scripts/dev run
   ```

   This builds the app and opens it from `~/Library/Developer/Xcode/DerivedData/Timezone-cli/Build/Products/Debug/Timezone.app`. Copy it to `/Applications` if you want to keep it.

Because the app is built locally, Launch at login may need approval in System Settings the first time.

## Development

- [AGENTS.md](AGENTS.md): build, test and triage setup, for people and coding agents. Run `scripts/dev test` for the fast loop.
- [GLOSSARY.md](GLOSSARY.md): the project's vocabulary (Zone, Home zone, Timeline, Cursor, …).
- [docs/adr/](docs/adr/): architecture decisions.

## Credits

City search uses data from [GeoNames](https://www.geonames.org/) (CC BY 4.0).
