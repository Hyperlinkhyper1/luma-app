/// Unit tables behind the ☰ converter in the Calculator's header.
///
/// Every unit says how to reach its category's base unit, which keeps one
/// formula for all of them: `base = value × factor + offset`. Only temperature
/// actually needs the offset, but expressing it this way means Celsius doesn't
/// have to be a special case in the UI.
library;

class ConvertUnit {
  const ConvertUnit(
    this.id,
    this.name,
    this.symbol,
    this.factor, [
    this.offset = 0,
  ]);

  final String id;
  final String name;

  /// Short form shown next to a value ("km", "°C").
  final String symbol;

  final double factor;
  final double offset;

  double toBase(double value) => value * factor + offset;
  double fromBase(double value) => (value - offset) / factor;
}

class ConvertCategory {
  const ConvertCategory(this.id, this.name, this.units);

  final String id;
  final String name;
  final List<ConvertUnit> units;

  ConvertUnit unitById(String id) =>
      units.firstWhere((u) => u.id == id, orElse: () => units.first);
}

/// Converts [value] between two units of the same category.
double convertUnits(double value, ConvertUnit from, ConvertUnit to) =>
    to.fromBase(from.toBase(value));

const unitCategories = <ConvertCategory>[
  ConvertCategory('length', 'Length', [
    ConvertUnit('km', 'Kilometre', 'km', 1000),
    ConvertUnit('m', 'Metre', 'm', 1),
    ConvertUnit('cm', 'Centimetre', 'cm', 0.01),
    ConvertUnit('mm', 'Millimetre', 'mm', 0.001),
    ConvertUnit('mi', 'Mile', 'mi', 1609.344),
    ConvertUnit('yd', 'Yard', 'yd', 0.9144),
    ConvertUnit('ft', 'Foot', 'ft', 0.3048),
    ConvertUnit('in', 'Inch', 'in', 0.0254),
    ConvertUnit('nmi', 'Nautical mile', 'nmi', 1852),
  ]),
  ConvertCategory('mass', 'Weight', [
    ConvertUnit('t', 'Tonne', 't', 1000),
    ConvertUnit('kg', 'Kilogram', 'kg', 1),
    ConvertUnit('g', 'Gram', 'g', 0.001),
    ConvertUnit('mg', 'Milligram', 'mg', 0.000001),
    ConvertUnit('lb', 'Pound', 'lb', 0.45359237),
    ConvertUnit('oz', 'Ounce', 'oz', 0.028349523125),
    ConvertUnit('st', 'Stone', 'st', 6.35029318),
  ]),
  ConvertCategory('temperature', 'Temperature', [
    ConvertUnit('c', 'Celsius', '°C', 1, 273.15),
    ConvertUnit('f', 'Fahrenheit', '°F', 5 / 9, 273.15 - 32 * 5 / 9),
    ConvertUnit('k', 'Kelvin', 'K', 1),
  ]),
  ConvertCategory('speed', 'Speed', [
    ConvertUnit('kmh', 'Kilometres per hour', 'km/h', 1 / 3.6),
    ConvertUnit('ms', 'Metres per second', 'm/s', 1),
    ConvertUnit('mph', 'Miles per hour', 'mph', 0.44704),
    ConvertUnit('kn', 'Knot', 'kn', 1852 / 3600),
    ConvertUnit('fts', 'Feet per second', 'ft/s', 0.3048),
  ]),
  ConvertCategory('area', 'Area', [
    ConvertUnit('km2', 'Square kilometre', 'km²', 1000000),
    ConvertUnit('ha', 'Hectare', 'ha', 10000),
    ConvertUnit('m2', 'Square metre', 'm²', 1),
    ConvertUnit('cm2', 'Square centimetre', 'cm²', 0.0001),
    ConvertUnit('mi2', 'Square mile', 'mi²', 2589988.110336),
    ConvertUnit('acre', 'Acre', 'ac', 4046.8564224),
    ConvertUnit('yd2', 'Square yard', 'yd²', 0.83612736),
    ConvertUnit('ft2', 'Square foot', 'ft²', 0.09290304),
  ]),
  ConvertCategory('volume', 'Volume', [
    ConvertUnit('m3', 'Cubic metre', 'm³', 1000),
    ConvertUnit('l', 'Litre', 'L', 1),
    ConvertUnit('ml', 'Millilitre', 'mL', 0.001),
    ConvertUnit('galus', 'Gallon (US)', 'gal', 3.785411784),
    ConvertUnit('galuk', 'Gallon (UK)', 'gal UK', 4.54609),
    ConvertUnit('qt', 'Quart (US)', 'qt', 0.946352946),
    ConvertUnit('pt', 'Pint (US)', 'pt', 0.473176473),
    ConvertUnit('cup', 'Cup (US)', 'cup', 0.2365882365),
    ConvertUnit('floz', 'Fluid ounce (US)', 'fl oz', 0.0295735295625),
    ConvertUnit('tbsp', 'Tablespoon (US)', 'tbsp', 0.01478676478125),
    ConvertUnit('tsp', 'Teaspoon (US)', 'tsp', 0.00492892159375),
  ]),
  ConvertCategory('time', 'Time', [
    ConvertUnit('ms', 'Millisecond', 'ms', 0.001),
    ConvertUnit('s', 'Second', 's', 1),
    ConvertUnit('min', 'Minute', 'min', 60),
    ConvertUnit('h', 'Hour', 'h', 3600),
    ConvertUnit('d', 'Day', 'd', 86400),
    ConvertUnit('wk', 'Week', 'wk', 604800),
    ConvertUnit('mo', 'Month (30 days)', 'mo', 2592000),
    ConvertUnit('yr', 'Year (365 days)', 'yr', 31536000),
  ]),
  ConvertCategory('data', 'Data', [
    ConvertUnit('bit', 'Bit', 'bit', 0.125),
    ConvertUnit('b', 'Byte', 'B', 1),
    ConvertUnit('kb', 'Kilobyte', 'kB', 1000),
    ConvertUnit('mb', 'Megabyte', 'MB', 1000000),
    ConvertUnit('gb', 'Gigabyte', 'GB', 1000000000),
    ConvertUnit('tb', 'Terabyte', 'TB', 1000000000000),
    ConvertUnit('kib', 'Kibibyte', 'KiB', 1024),
    ConvertUnit('mib', 'Mebibyte', 'MiB', 1048576),
    ConvertUnit('gib', 'Gibibyte', 'GiB', 1073741824),
    ConvertUnit('tib', 'Tebibyte', 'TiB', 1099511627776),
  ]),
  ConvertCategory('pressure', 'Pressure', [
    ConvertUnit('pa', 'Pascal', 'Pa', 1),
    ConvertUnit('hpa', 'Hectopascal', 'hPa', 100),
    ConvertUnit('kpa', 'Kilopascal', 'kPa', 1000),
    ConvertUnit('bar', 'Bar', 'bar', 100000),
    ConvertUnit('mbar', 'Millibar', 'mbar', 100),
    ConvertUnit('atm', 'Atmosphere', 'atm', 101325),
    ConvertUnit('psi', 'Pound per square inch', 'psi', 6894.757293168361),
    ConvertUnit('mmhg', 'Millimetre of mercury', 'mmHg', 133.322387415),
  ]),
  ConvertCategory('energy', 'Energy', [
    ConvertUnit('j', 'Joule', 'J', 1),
    ConvertUnit('kj', 'Kilojoule', 'kJ', 1000),
    ConvertUnit('cal', 'Calorie', 'cal', 4.184),
    ConvertUnit('kcal', 'Kilocalorie', 'kcal', 4184),
    ConvertUnit('wh', 'Watt hour', 'Wh', 3600),
    ConvertUnit('kwh', 'Kilowatt hour', 'kWh', 3600000),
    ConvertUnit('btu', 'British thermal unit', 'BTU', 1055.05585262),
  ]),
  ConvertCategory('angle', 'Angle', [
    ConvertUnit('deg', 'Degree', '°', 1),
    ConvertUnit('rad', 'Radian', 'rad', 57.29577951308232),
    ConvertUnit('grad', 'Gradian', 'grad', 0.9),
    ConvertUnit('turn', 'Turn', 'turn', 360),
    ConvertUnit('arcmin', 'Arcminute', "'", 1 / 60),
    ConvertUnit('arcsec', 'Arcsecond', '"', 1 / 3600),
  ]),
];

ConvertCategory categoryById(String id) =>
    unitCategories.firstWhere((c) => c.id == id,
        orElse: () => unitCategories.first);
