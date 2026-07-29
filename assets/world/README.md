# World map outline

`world_countries.json` is the country outline behind the travel map in
Account → Stats.

- **Source**: [Natural Earth](https://www.naturalearthdata.com) 1:50m Admin 0 –
  Countries (`ne_50m_admin_0_countries`). Natural Earth is public domain, no
  attribution required.
- **Processing**: outer rings only, Douglas-Peucker simplified at ~0.2° (0.05°
  for small shapes), quantised to 1/20°, at most 14 rings per country, features
  sharing an ISO code merged, Antarctica dropped. 237 countries, ~100 KiB.

Format:

```jsonc
{
  "q": 20,                        // coordinates are integers of 1/q degrees
  "countries": [
    {
      "c": "NL",                  // ISO 3166-1 alpha-2 (3-letter where none exists)
      "n": "Netherlands",
      "r": "Europe",              // continent, used to group the picker
      "p": [[lon, lat, lon, lat]] // one flat coordinate list per ring
    }
  ]
}
```

`lib/account/travel/world_map_data.dart` parses it and projects every point
once (Miller cylindrical) into the unit square.
