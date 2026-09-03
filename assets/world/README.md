# World map outline

`world_countries.json` is the country outline behind the travel map in
Account → Stats.

- **Source**: [Natural Earth](https://www.naturalearthdata.com) 1:10m Admin 0 –
  Countries (`ne_10m_admin_0_countries`). Natural Earth is public domain, no
  attribution required.
- **Processing**: outer rings only; Douglas-Peucker simplified at 0.04° for
  landmasses over 20 square degrees, 0.015° down to 1, and 0.005° below that;
  quantised to 1/100° (≈1.1 km); rings under 0.002 square degrees (≈25 km²)
  dropped unless they're the country's largest; at most 60 rings per country;
  features sharing an ISO code merged; Antarctica dropped. A country whose
  outline is finer than the grid (Vatican City) keeps a minimum square so it
  stays listed and tappable. 248 countries, ~106k points, ~300 KiB.

Format:

```jsonc
{
  "q": 100,                  // coordinates are integers of 1/q degrees
  "countries": [
    {
      "c": "NL",             // ISO 3166-1 alpha-2 (3-letter where none exists)
      "n": "Netherlands",
      "r": "Europe",         // continent, used to group the picker
      "p": [124, 31, 12]     // number of points in each of this country's rings
    }
  ],
  "points": "…base64…"       // every ring's coordinates, back to back
}
```

The `points` blob holds each ring's points as zigzag-varint deltas (x then y,
each ring starting from 0), in the order the countries and their rings are
listed. Storing coordinates this way instead of as JSON numbers keeps the file
about a third of the size and turns parsing into a byte loop.

`lib/account/travel/world_map_data.dart` decodes it and projects every point
once (Miller cylindrical) into the unit square;
`test/world_map_fixture.dart` writes the same format independently so the
decoder is pinned by tests.
