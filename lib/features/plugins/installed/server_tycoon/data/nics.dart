// Auto-ported from Roblox Server Hosting Tycoon

enum NICInterfaceType { onboard, pcie }

class NIC {
  final String id;
  final String name;
  final int throughputMbps;
  final NICInterfaceType interfaceType;
  final int powerDrawWatts;
  final int price;

  const NIC({
    required this.id,
    required this.name,
    required this.throughputMbps,
    required this.interfaceType,
    required this.powerDrawWatts,
    required this.price,
  });
}

final Map<String, NIC> nicsById = {
  'REALTEK_ONBOARD': const NIC(
    id: 'REALTEK_ONBOARD',
    name: 'Realtek Gigabit Ethernet (onboard)',
    throughputMbps: 1000,
    interfaceType: NICInterfaceType.onboard,
    powerDrawWatts: 2,
    price: 0,
  ),
  'TPLINK_10G_CARD': const NIC(
    id: 'TPLINK_10G_CARD',
    name: 'TP-Link TX401 10GbE PCIe Card',
    throughputMbps: 10000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 5,
    price: 480,
  ),
  'INTEL_X520': const NIC(
    id: 'INTEL_X520',
    name: 'Intel X520-DA2 10GbE SFP+ Dual Port',
    throughputMbps: 20000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 8,
    price: 1200,
  ),
  'MELLANOX_CONNECTX5_25G': const NIC(
    id: 'MELLANOX_CONNECTX5_25G',
    name: 'Mellanox ConnectX-5 25GbE Dual Port',
    throughputMbps: 50000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 12,
    price: 3200,
  ),
  'BROADCOM_25G': const NIC(
    id: 'BROADCOM_25G',
    name: 'Broadcom P225P 25GbE Dual Port',
    throughputMbps: 50000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 11,
    price: 2900,
  ),
  'MELLANOX_CONNECTX6_100G': const NIC(
    id: 'MELLANOX_CONNECTX6_100G',
    name: 'Mellanox ConnectX-6 100GbE Dual Port',
    throughputMbps: 200000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 22,
    price: 9800,
  ),
  'INTEL_I225V': const NIC(
    id: 'INTEL_I225V',
    name: 'Intel I225-V 2.5GbE PCIe Card',
    throughputMbps: 2500,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 3,
    price: 180,
  ),
  'AQUANTIA_AQC111': const NIC(
    id: 'AQUANTIA_AQC111',
    name: 'Marvell AQtion 5GbE PCIe Card',
    throughputMbps: 5000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 4,
    price: 290,
  ),
  'NVIDIA_CONNECTX7_200G': const NIC(
    id: 'NVIDIA_CONNECTX7_200G',
    name: 'NVIDIA ConnectX-7 200GbE Dual Port',
    throughputMbps: 400000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 28,
    price: 24000,
  ),
  'NVIDIA_BLUEFIELD3_400G': const NIC(
    id: 'NVIDIA_BLUEFIELD3_400G',
    name: 'NVIDIA BlueField-3 400GbE SmartNIC',
    throughputMbps: 800000,
    interfaceType: NICInterfaceType.pcie,
    powerDrawWatts: 60,
    price: 52000,
  ),
};

late final List<NIC> nicList = nicsById.values.toList()
  ..sort((a, b) => a.price.compareTo(b.price));
