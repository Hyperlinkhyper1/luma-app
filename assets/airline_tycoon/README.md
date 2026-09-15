# Airline Tycoon airport data

`airports.json` is the world the Airline Tycoon plugin flies around. It is
read once at runtime by
`lib/features/plugins/installed/airline_tycoon/data/airport_catalog.dart`.

- **Source**: airport names, IATA codes, cities, countries, coordinates and
  longest-runway lengths follow [OurAirports](https://ourairports.com/data/),
  which its maintainers dedicate to the **public domain** — no attribution
  required and no share-alike obligation. OpenFlights was deliberately not
  used: it is ODbL, which would make the share-alike terms travel with this
  repository.
- **Selection**: 181 airports, one or two per metro area, chosen for scheduled
  passenger traffic and spread deliberately across every inhabited region so
  the map does not read as Europe plus a few outliers.
- **`catchment`** is *not* third-party data. It is a 1–100 demand score
  written for game balance — roughly how large a market the city is — and
  feeds `Economy.demandPerDay`. Tune it freely; nothing outside the plugin
  reads it.
- **Coordinates** are the airport reference point in decimal degrees, rounded
  to four places (about 11 m, far finer than a game needs). **Runway lengths**
  are the longest runway in metres, rounded to 10 m, and decide which aircraft
  the field can take.

Format:

```jsonc
{
  "format": 1,
  "airports": [
    {
      "iata": "AMS",
      "name": "Amsterdam Schiphol",
      "city": "Amsterdam",
      "country": "NL",     // ISO 3166-1 alpha-2
      "lat": 52.3105,
      "lon": 4.7683,
      "runwayM": 3800,     // longest runway, metres
      "catchment": 84      // derived demand score, 1-100
    }
  ]
}
```

Unlike `assets/world/world_countries.json`, this file is small enough
(~26 KiB over 181 rows) that plain JSON numbers cost nothing, so there is no
quantisation or delta-encoding to undo — `AirportCatalog.parse` is a straight
`jsonDecode`. Rows that are malformed or missing a required field are skipped
rather than throwing, so a bad edit degrades the world instead of breaking
the plugin.

The file is generated, but the generator is a one-off: editing this JSON
directly is fine and expected.
