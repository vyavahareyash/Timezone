# Bundled GeoNames city list for Zone search

Zone search uses a bundled GeoNames `cities15000` extract (city name, country, IANA time zone; ~1–2 MB) instead of Foundation's `TimeZone.knownTimeZoneIdentifiers` or online `CLGeocoder`. The built-in identifiers only name ~400 cities, so common searches like "Pune" (Asia/Kolkata) or "San Francisco" (America/Los_Angeles) find nothing; `CLGeocoder` needs network and is rate-limited. The data is CC-BY 4.0, so the app must carry a GeoNames attribution.
