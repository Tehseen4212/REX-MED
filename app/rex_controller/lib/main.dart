import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as ble;
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'controller_page.dart';

void main() {
  runApp(const MaterialApp(
    home: ControllerPage(), // Now opens directly to the controller page
    debugShowCheckedModeBanner: false,
  ));
}

class RexUniversalBluetooth extends StatefulWidget {
  const RexUniversalBluetooth({super.key});

  @override
  State<RexUniversalBluetooth> createState() => _RexUniversalBluetoothState();
}

class _RexUniversalBluetoothState extends State<RexUniversalBluetooth> {
  final classic.FlutterBluetoothSerial bluetoothClassic =
      classic.FlutterBluetoothSerial.instance;

  List<classic.BluetoothDevice> pairedDevices = [];
  List<ble.ScanResult> bleDevices = [];
  Map<String, bool> connectionStatus = {};
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await requestPermissions();
    // After permissions are handled (granted or denied), try loading devices safely.
    await loadPairedDevices();
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> loadPairedDevices() async {
    try {
      pairedDevices = await bluetoothClassic.getBondedDevices();
      for (var d in pairedDevices) {
        connectionStatus[d.address] = d.isConnected;
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Error loading paired devices: $e");
    }
  }

  void startBleScan() async {
    if (!mounted) return;
    setState(() {
      isScanning = true;
      bleDevices.clear();
    });

    try {
      ble.FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      ble.FlutterBluePlus.scanResults.listen((results) {
        if (mounted) setState(() => bleDevices = results);
      });

      ble.FlutterBluePlus.isScanning.listen((scanning) {
        if (mounted) setState(() => isScanning = scanning);
      });
    } catch (e) {
      debugPrint("BLE scan error: $e");
    }
  }

  void stopBleScan() {
    ble.FlutterBluePlus.stopScan();
    if (mounted) setState(() => isScanning = false);
  }

  // ✅ CLASSIC (HC-05, HC-06, etc.)
  Future<void> connectClassic(classic.BluetoothDevice device) async {
    try {
      final connection =
          await classic.BluetoothConnection.toAddress(device.address);

      if (connection.isConnected) {
        setState(() {
          connectionStatus[device.address] = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Connected to ${device.name ?? 'Device'}")),
        );

        // Navigate directly to controller page, replace the entire stack
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ControllerPage(device: device, connection: connection),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Connection failed.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("⚠️ Cannot connect directly. Opening Bluetooth settings...")),
      );
      openSystemBluetoothSettings();
    }
  }

  // ✅ BLE DEVICES (Smart bands, BLE sensors, etc.)
  Future<void> connectBleDevice(ble.BluetoothDevice device) async {
    try {
      await device.connect();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "✅ Connected to ${device.platformName.isEmpty ? 'BLE Device' : device.platformName}")),
      );

      // Navigate to controller page (simulate BLE connection object)
      final fakeConnection = await _createFakeConnection(device);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => ControllerPage(
            device: classic.BluetoothDevice(
              name: device.platformName,
              address: device.remoteId.str,
              type: classic.BluetoothDeviceType.unknown,
            ),
            connection: fakeConnection,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ BLE connection failed: $e")),
      );
    }
  }

  // This creates a "fake" BluetoothConnection object to make the BLE interface compatible with ControllerPage
  Future<classic.BluetoothConnection> _createFakeConnection(
      ble.BluetoothDevice device) async {
    // NOTE: For BLE, actual SPP-style connection is not supported.
    // This dummy connection avoids null errors in ControllerPage.
    final serverSocket =
        await classic.BluetoothConnection.toAddress("00:00:00:00:00:00")
            .catchError((_) => null);
    return serverSocket ?? (throw Exception("BLE does not support SPP data."));
  }

  Future<void> openSystemBluetoothSettings() async {
    const url = 'android.settings.BLUETOOTH_SETTINGS';
    try {
      await launchUrl(Uri(scheme: 'android', path: url));
    } catch (_) {
      await launchUrl(Uri.parse('package:com.android.settings'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Device to Connect"),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: Icon(isScanning ? Icons.stop : Icons.refresh),
            onPressed: isScanning ? stopBleScan : startBleScan,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => loadPairedDevices(),
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("🔹 Paired Devices (Classic)",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
            if (pairedDevices.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text("No paired classic devices found.",
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ),
            ...pairedDevices.map((d) => ListTile(
                  leading: Icon(
                    Icons.devices_other,
                    color: connectionStatus[d.address] == true
                        ? Colors.green
                        : Colors.grey,
                  ),
                  title: Text(d.name ?? "Unknown Device"),
                  subtitle: Text(d.address),
                  trailing: connectionStatus[d.address] == true
                      ? const Text("Connected",
                          style: TextStyle(color: Colors.green))
                      : const Text("Not Connected",
                          style: TextStyle(color: Colors.grey)),
                  onTap: () => connectClassic(d),
                )),
            const Divider(),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text("🔹 Nearby BLE Devices (Unpaired)",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
            ),
            if (bleDevices.isEmpty && !isScanning)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text("No BLE devices found. Tap refresh to scan.",
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ),
            if (isScanning)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
            ...bleDevices.map((r) => ListTile(
                  leading: const Icon(Icons.bluetooth_searching),
                  title: Text(r.device.platformName.isNotEmpty
                      ? r.device.platformName
                      : "Unknown BLE Device"),
                  subtitle: Text(r.device.remoteId.str),
                  onTap: () async => connectBleDevice(r.device),
                )),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                "ℹ️ Tip: For headphones or speakers, Android blocks direct app connections.\nTap the device to open Bluetooth settings and connect manually.",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
