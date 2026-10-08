// Auto-ported from Roblox Server Hosting Tycoon


import '../../../../../l10n/current_l.dart';

enum NICInterfaceType { onboard, pcie }

class NIC {
  final String id;
  final int throughputMbps;
  final NICInterfaceType interfaceType;
  final int powerDrawWatts;
  final int price;

  const NIC({
    required this.id,
    required this.throughputMbps,
    required this.interfaceType,
    required this.powerDrawWatts,
    required this.price,
  });

  String get name => switch (id) {
        'REALTEK_ONBOARD' => currentL.serverTycoonNicRealtekOnboard,
        'TPLINK_10G_CARD' => 'TP-Link TX401 10GbE PCIe Card',
        'INTEL_X520' => 'Intel X520-DA2 10GbE SFP+ Dual Port',
        'MELLANOX_CONNECTX5_25G' => 'Mellanox ConnectX-5 25GbE Dual Port',
        'BROADCOM_25G' => 'Broadcom P225P 25GbE Dual Port',
        'MELLANOX_CONNECTX6_100G' => 'Mellanox ConnectX-6 100GbE Dual Port',
        'INTEL_I225V' => 'Intel I225-V 2.5GbE PCIe Card',
        'AQUANTIA_AQC111' => 'Marvell AQtion 5GbE PCIe Card',
        'NVIDIA_CONNECTX7_200G' => 'NVIDIA ConnectX-7 200GbE Dual Port',
        'NVIDIA_BLUEFIELD3_400G' => 'NVIDIA BlueField-3 400GbE SmartNIC',
        'GENERIC_100M_ONBOARD' => currentL.serverTycoonNicGenericOnboard,
        'INTEL_X710_40G' => 'Intel X710 40GbE QSFP+ Dual Port',
        _ => id,
      };
}

final Map<String, NIC> nicsById = {
  'REALTEK_ONBOARD': const NIC(
    id: 'REALTEK_ONBOARD',
    throughputMbps: 1000,
    interfaceType: NICInterfaceType.onboard,
    powerDrawWatts: 2,
    price: 0,
  ),
  'TPLINK_10G_CARD': const NIC(
    id: 'TPLINK_10G_CARD',
    throughputMbps: 10000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 5,
    price: 480,
  ),
  'INTEL_X520': const NIC(
    id: 'INTEL_X520',
    throughputMbps: 20000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 8,
    price: 1200,
  ),
  'MELLANOX_CONNECTX5_25G': const NIC(
    id: 'MELLANOX_CONNECTX5_25G',
    throughputMbps: 50000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 12,
    price: 3200,
  ),
  'BROADCOM_25G': const NIC(
    id: 'BROADCOM_25G',
    throughputMbps: 50000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 11,
    price: 2900,
  ),
  'MELLANOX_CONNECTX6_100G': const NIC(
    id: 'MELLANOX_CONNECTX6_100G',
    throughputMbps: 200000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 22,
    price: 9800,
  ),
  'INTEL_I225V': const NIC(
    id: 'INTEL_I225V',
    throughputMbps: 2500,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 3,
    price: 180,
  ),
  'AQUANTIA_AQC111': const NIC(
    id: 'AQUANTIA_AQC111',
    throughputMbps: 5000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 4,
    price: 290,
  ),
  'NVIDIA_CONNECTX7_200G': const NIC(
    id: 'NVIDIA_CONNECTX7_200G',
    throughputMbps: 400000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 28,
    price: 24000,
  ),
  'NVIDIA_BLUEFIELD3_400G': const NIC(
    id: 'NVIDIA_BLUEFIELD3_400G',
    throughputMbps: 800000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 60,
    price: 52000,
  ),
  'GENERIC_100M_ONBOARD': const NIC(
    id: 'GENERIC_100M_ONBOARD',
    throughputMbps: 100,
    interfaceType: NICInterfaceType.onboard,
    powerDrawWatts: 1,
    price: 0,
  ),
  'INTEL_X710_40G': const NIC(
    id: 'INTEL_X710_40G',
    throughputMbps: 80000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 14,
    price: 4200,
  ),
};

late final List<NIC> nicList = nicsById.values.toList()
  ..sort((a, b) => a.price.compareTo(b.price));
