// Auto-ported from Roblox Server Hosting Tycoon

import 'motherboards.dart';
import '../../../../../l10n/current_l.dart';

class RAMStick {
  final String id;
  final RAMType ramType;
  final int capacityGB;
  final int speedMHz;
  final bool ecc;
  final bool registered;
  final int price;

  const RAMStick({
    required this.id,
    required this.ramType,
    required this.capacityGB,
    required this.speedMHz,
    required this.ecc,
    required this.registered,
    required this.price,
  });

  String get name => switch (id) {
        'DDR3_8GB' => currentL.serverTycoonRamGenericDdr3Gb8,
        'DDR3_16GB' => 'Kingston DDR3 16GB 1866MHz',
        'DDR4_8GB' => 'Corsair Vengeance DDR4 8GB 3200MHz',
        'DDR4_16GB' => 'Corsair Vengeance DDR4 16GB 3200MHz',
        'DDR4_32GB' => 'G.Skill Ripjaws DDR4 32GB 3600MHz',
        'DDR4_32GB_ECC' => 'Samsung DDR4 32GB ECC 2933MHz',
        'DDR4_64GB_RDIMM' => 'Micron DDR4 64GB ECC RDIMM 2933MHz',
        'DDR5_32GB' => 'Corsair Dominator DDR5 32GB 6000MHz',
        'DDR5_64GB' => 'G.Skill Trident Z5 DDR5 64GB 6000MHz',
        'DDR5_128GB_RDIMM' => 'SK Hynix DDR5 128GB ECC RDIMM 4800MHz',
        'DDR3_8GB_ECC' => 'Hynix DDR3 8GB ECC 1600MHz',
        'DDR4_16GB_ECC' => 'Kingston DDR4 16GB ECC 3200MHz',
        'DDR4_32GB_RDIMM2' => 'Samsung DDR4 32GB ECC RDIMM 3200MHz',
        'DDR4_128GB_LRDIMM' => 'Micron DDR4 128GB ECC LRDIMM 2933MHz',
        'DDR5_48GB' => 'Corsair Vengeance DDR5 48GB 5600MHz',
        'DDR5_96GB_RDIMM' => 'Samsung DDR5 96GB ECC RDIMM 5600MHz',
        'DDR5_256GB_RDIMM' => 'Micron DDR5 256GB ECC RDIMM 4800MHz',
        'DDR3_4GB' => currentL.serverTycoonRamGenericDdr3Gb4,
        'DDR5_16GB' => 'Kingston Fury DDR5 16GB 5200MHz',
        'DDR5_32GB_ECC' => 'Crucial DDR5 32GB ECC UDIMM 4800MHz',
        _ => id,
      };
}

final Map<String, RAMStick> ramById = {
  'DDR3_8GB': const RAMStick(
    id: 'DDR3_8GB',
    ramType: RAMType.ddr3,
    capacityGB: 8,
    speedMHz: 1600,
    ecc: false,
    registered: false,
    price: 0,
  ),
  'DDR3_16GB': const RAMStick(
    id: 'DDR3_16GB',
    ramType: RAMType.ddr3,
    capacityGB: 16,
    speedMHz: 1866,
    ecc: false,
    registered: false,
    price: 220,
  ),
  'DDR4_8GB': const RAMStick(
    id: 'DDR4_8GB',
    ramType: RAMType.ddr4,
    capacityGB: 8,
    speedMHz: 3200,
    ecc: false,
    registered: false,
    price: 180,
  ),
  'DDR4_16GB': const RAMStick(
    id: 'DDR4_16GB',
    ramType: RAMType.ddr4,
    capacityGB: 16,
    speedMHz: 3200,
    ecc: false,
    registered: false,
    price: 340,
  ),
  'DDR4_32GB': const RAMStick(
    id: 'DDR4_32GB',
    ramType: RAMType.ddr4,
    capacityGB: 32,
    speedMHz: 3600,
    ecc: false,
    registered: false,
    price: 680,
  ),
  'DDR4_32GB_ECC': const RAMStick(
    id: 'DDR4_32GB_ECC',
    ramType: RAMType.ddr4,
    capacityGB: 32,
    speedMHz: 2933,
    ecc: true,
    registered: false,
    price: 950,
  ),
  'DDR4_64GB_RDIMM': const RAMStick(
    id: 'DDR4_64GB_RDIMM',
    ramType: RAMType.ddr4,
    capacityGB: 64,
    speedMHz: 2933,
    ecc: true,
    registered: true,
    price: 2100,
  ),
  'DDR5_32GB': const RAMStick(
    id: 'DDR5_32GB',
    ramType: RAMType.ddr5,
    capacityGB: 32,
    speedMHz: 6000,
    ecc: false,
    registered: false,
    price: 1050,
  ),
  'DDR5_64GB': const RAMStick(
    id: 'DDR5_64GB',
    ramType: RAMType.ddr5,
    capacityGB: 64,
    speedMHz: 6000,
    ecc: false,
    registered: false,
    price: 2200,
  ),
  'DDR5_128GB_RDIMM': const RAMStick(
    id: 'DDR5_128GB_RDIMM',
    ramType: RAMType.ddr5,
    capacityGB: 128,
    speedMHz: 4800,
    ecc: true,
    registered: true,
    price: 5400,
  ),
  'DDR3_8GB_ECC': const RAMStick(
    id: 'DDR3_8GB_ECC',
    ramType: RAMType.ddr3,
    capacityGB: 8,
    speedMHz: 1600,
    ecc: true,
    registered: false,
    price: 140,
  ),
  'DDR4_16GB_ECC': const RAMStick(
    id: 'DDR4_16GB_ECC',
    ramType: RAMType.ddr4,
    capacityGB: 16,
    speedMHz: 3200,
    ecc: true,
    registered: false,
    price: 480,
  ),
  'DDR4_32GB_RDIMM2': const RAMStick(
    id: 'DDR4_32GB_RDIMM2',
    ramType: RAMType.ddr4,
    capacityGB: 32,
    speedMHz: 3200,
    ecc: true,
    registered: true,
    price: 1100,
  ),
  'DDR4_128GB_LRDIMM': const RAMStick(
    id: 'DDR4_128GB_LRDIMM',
    ramType: RAMType.ddr4,
    capacityGB: 128,
    speedMHz: 2933,
    ecc: true,
    registered: true,
    price: 4300,
  ),
  'DDR5_48GB': const RAMStick(
    id: 'DDR5_48GB',
    ramType: RAMType.ddr5,
    capacityGB: 48,
    speedMHz: 5600,
    ecc: false,
    registered: false,
    price: 1550,
  ),
  'DDR5_96GB_RDIMM': const RAMStick(
    id: 'DDR5_96GB_RDIMM',
    ramType: RAMType.ddr5,
    capacityGB: 96,
    speedMHz: 5600,
    ecc: true,
    registered: true,
    price: 4200,
  ),
  'DDR5_256GB_RDIMM': const RAMStick(
    id: 'DDR5_256GB_RDIMM',
    ramType: RAMType.ddr5,
    capacityGB: 256,
    speedMHz: 4800,
    ecc: true,
    registered: true,
    price: 11800,
  ),
  'DDR3_4GB': const RAMStick(
    id: 'DDR3_4GB',
    ramType: RAMType.ddr3,
    capacityGB: 4,
    speedMHz: 1333,
    ecc: false,
    registered: false,
    price: 40,
  ),
  'DDR5_16GB': const RAMStick(
    id: 'DDR5_16GB',
    ramType: RAMType.ddr5,
    capacityGB: 16,
    speedMHz: 5200,
    ecc: false,
    registered: false,
    price: 620,
  ),
  'DDR5_32GB_ECC': const RAMStick(
    id: 'DDR5_32GB_ECC',
    ramType: RAMType.ddr5,
    capacityGB: 32,
    speedMHz: 4800,
    ecc: true,
    registered: false,
    price: 1200,
  ),
};

late final List<RAMStick> ramList = ramById.values.toList()
  ..sort((a, b) => a.price.compareTo(b.price));
