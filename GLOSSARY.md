# Timezone

A macOS menu bar tool for converting a single moment across several time zones at a glance, mainly to pick meeting times.

## Language

**Zone**:
A user-chosen label paired with a time zone; the panel shows each one as a Row.
_Avoid_: Clock, city, location

**City**:
An entry in the bundled GeoNames list (name, country, time zone) that the user searches to add a Zone; choosing one creates a Zone labelled with its name.
_Avoid_: Location, place

**Row**:
How the panel shows one Zone at the Cursor: its label, local time, Day offset and abbreviation, beside its hour strip.
_Avoid_: Line, entry

**Home zone**:
The Zone matching the Mac's current system time zone; always first, and its day defines the Timeline.
_Avoid_: Local zone, primary zone, default zone

**Timeline**:
Today in the Home zone, from midnight to midnight, that every Zone is laid out against; usually 24 hours, but 23 or 25 on a Home-zone DST change day.
_Avoid_: Axis, ruler, day view

**Cursor**:
The single moment the user is inspecting, shown in every Zone's local time at once; drawn as a vertical line through every strip.
_Avoid_: Selected time, probe, slider

**Cursor handle**:
The knob at the top of the Cursor line: drag it (or press anywhere on a strip) to move the Cursor; when focused, ← / → move it 15 minutes.
_Avoid_: Thumb, knob, scrubber

**Now**:
The current real-world moment, marked on the Timeline and the Cursor's starting position.
_Avoid_: Current time, today marker

**Following Now**:
The Cursor's state before the user first moves it: it tracks Now as time passes. Moving the Cursor ends it; returning to Now restores it.
_Avoid_: Live mode, auto mode

**Day offset**:
How a Zone's local date at the Cursor differs from the Home zone's date (−1, 0, +1).
_Avoid_: Date shift, day badge

**Working hours**:
The fixed 09:00–18:00 local-time band highlighted in every Zone, so a glance shows whether the Cursor falls in someone's workday.
_Avoid_: Business hours, office hours, daytime
