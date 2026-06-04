import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as classic;
import 'main.dart';

/// ControllerPage — polished UI, animations, exact UI specifications matched
class ControllerPage extends StatefulWidget {
  final classic.BluetoothDevice? device;
  final classic.BluetoothConnection? connection;

  const ControllerPage({
    super.key,
    this.device,
    this.connection,
  });

  @override
  State<ControllerPage> createState() => _ControllerPageState();
}

class _ControllerPageState extends State<ControllerPage> with TickerProviderStateMixin {
  // Connection & robot state
  bool isConnected = false;
  bool lineModeActive = false;
  String robotState = "Idle";
  double distanceMeters = 0.0;
  String currentCabin = "None";
  bool obstacle = false;
  String lastError = "";

  // Logs
  final List<String> logs = [];

  // Text controllers
  final TextEditingController _aiController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();

  // Animation controllers
  late final AnimationController _pageInController;
  late final Animation<Offset> _pageSlide;
  late final Animation<double> _pageFade;

  late final AnimationController _exitController;
  late final Animation<double> _exitScale;
  late final Animation<double> _exitFade;

  String _pressedButton = "";

  // Voice/text map
  final Map<String, String> _wordToCommand = {
    "forward": "F\n",
    "go": "F\n",
    "back": "B\n",
    "reverse": "B\n",
    "left": "L\n",
    "right": "R\n",
    "stop": "S\n",
    "line": "T\n",
    "follow": "T\n",
    "track": "T\n",
    "resume": "0\n",
    "deliver": "D\n",
    "rex": "REX\n",
    "hello": "I\n",
    "hi": "I\n",
    "hey": "I\n",
    "bye": "I\n",
    "battery": "I\n",
    "obstacle": "I\n",
  };

  @override
  void initState() {
    super.initState();

    isConnected = widget.connection?.isConnected ?? false;

    widget.connection?.input?.listen(_onDataReceived, onDone: _onDisconnected, onError: (e) {
      _addLog("⚠️ Connection error: $e");
      _setDisconnected();
    });

    _pageInController = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _pageSlide = Tween<Offset>(begin: const Offset(0.0, 0.06), end: Offset.zero).animate(
        CurvedAnimation(parent: _pageInController, curve: Curves.easeOutCubic));
    _pageFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _pageInController, curve: Curves.easeOutCubic));
    _pageInController.forward();

    _exitController = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _exitScale = Tween<double>(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic));
    _exitFade = Tween<double>(begin: 0.0, end: 1.0).animate(
    CurvedAnimation(parent: _exitController, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _pageInController.dispose();
    _exitController.dispose();
    _aiController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  void _onDataReceived(Uint8List data) {
    final text = String.fromCharCodes(data).trim();
    if (text.isEmpty) return;
    _addLog("📩 $text");

    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        _applyTelemetry(decoded);
        return;
      }
    } catch (_) {}

    if (text.startsWith("ACK:")) {
      final cmd = text.substring(4);
      _addLog("🔁 Acknowledged: $cmd");
    } else {
      _setRobotStateFromText(text);
    }
  }

  void _applyTelemetry(Map<String, dynamic> json) {
    setState(() {
      if (json.containsKey('state')) robotState = json['state'].toString();
      if (json.containsKey('distance')) {
        final v = json['distance'];
        if (v is num) distanceMeters = v.toDouble();
      }
      if (json.containsKey('destination')) currentCabin = json['destination'].toString();
      if (json.containsKey('obstacle')) obstacle = json['obstacle'] == true;
      if (json.containsKey('error')) lastError = json['error'].toString();
      if (json.containsKey('mode')) {
        final m = json['mode'].toString().toLowerCase();
        lineModeActive = m.contains('line');
      }
    });
  }

  void _setRobotStateFromText(String text) {
    final lower = text.toLowerCase();
    setState(() {
      if (lower.contains("moving forward") || lower.contains("forward")) robotState = "Moving Forward";
      else if (lower.contains("moving backward") || lower.contains("backward")) robotState = "Moving Backward";
      else if (lower.contains("turning left") || lower.contains("left")) robotState = "Turning Left";
      else if (lower.contains("turning right") || lower.contains("right")) robotState = "Turning Right";
      else if (lower.contains("stop") || lower.contains("stopped")) robotState = "Stopped";
      else if (lower.contains("line")) robotState = "Line Mode";
    });
  }

  void _onDisconnected() {
    _addLog("❌ Disconnected from device");
    _setDisconnected();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Device disconnected")));
    }
  }

  void _setDisconnected() {
    setState(() {
      isConnected = false;
      lineModeActive = false;
    });
  }

  void _addLog(String s) {
    final now = DateTime.now();
    final ts = "${now.hour.toString().padLeft(2, '0')}:"
        "${now.minute.toString().padLeft(2, '0')}:"
        "${now.second.toString().padLeft(2, '0')}";
    setState(() {
      logs.insert(0, "[$ts] $s");
      if (logs.length > 60) logs.removeLast();
    });
  }

  Future<void> sendCommand(String rawCmd, {bool log = true}) async {
    if (widget.connection == null) {
      _addLog("⚠️ Not connected; cannot send: $rawCmd");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Please connect to REX first")));
      return;
    }

    if (!isConnected && (widget.connection?.isConnected ?? false)) {
      setState(() => isConnected = true);
    }

    if (!isConnected) {
      _addLog("⚠️ Not connected; cannot send: $rawCmd");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Not connected")));
      return;
    }

    var cmd = rawCmd;
    if (!cmd.endsWith('\n')) cmd = "$cmd\n";

    int attempts = 0;
    while (attempts < 3) {
      attempts++;
      try {
        widget.connection!.output.add(Uint8List.fromList(cmd.codeUnits));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (log) _addLog("📤 Sent: ${cmd.replaceAll('\n', '\\n')}");
        _postSendStateUpdate(cmd);
        return;
      } catch (e) {
        _addLog("❌ Send attempt $attempts failed: $e");
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
    _addLog("❌ Failed to send command after 3 attempts: $cmd");
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Failed to send command")));
  }

  void _postSendStateUpdate(String cmdWithNewline) {
    final cmd = cmdWithNewline.trim();
    setState(() {
      if (cmd == "F") robotState = "Moving Forward";
      else if (cmd == "B") robotState = "Moving Backward";
      else if (cmd == "L") robotState = "Turning Left";
      else if (cmd == "R") robotState = "Turning Right";
      else if (cmd == "S") robotState = "Stopped";
      else if (cmd == "T") {
        robotState = "Line Tracking";
        lineModeActive = true;
      } else if (cmd == "0") {
        robotState = "Manual Mode";
        lineModeActive = false;
      } else if (cmd.startsWith("MOVE:")) robotState = "Moving ${cmd.substring(5)} m";
      else if (cmd == "D") robotState = "Delivering";
      else if (cmd == "I") robotState = "Interacting";
    });
  }

  String? _mapTextToCommand(String text) {
    final t = text.trim().toLowerCase();
    if (t.isEmpty) return null;
    if (_wordToCommand.containsKey(t)) return _wordToCommand[t];
    if (t.startsWith("move")) {
      final regex = RegExp(r"(-?\d+\.?\d*)");
      final match = regex.firstMatch(t);
      if (match != null) {
        final numStr = match.group(0);
        return "MOVE:$numStr\n";
      }
      return null;
    }
    for (final entry in _wordToCommand.entries) {
      if (t.contains(entry.key)) return entry.value;
    }
    return null;
  }

  Future<void> _onControlTap(String shortCmd) async {
    if (lineModeActive && (shortCmd != 'S')) {
      _addLog("⚠️ Manual controls disabled while Line Tracking is active.");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Line mode active — disable it first")));
      return;
    }
    setState(() => _pressedButton = shortCmd);
    await Future.delayed(const Duration(milliseconds: 120));
    setState(() => _pressedButton = "");
    await sendCommand(shortCmd);
  }

  Future<void> _sendMoveMeters() async {
    final v = _distanceController.text.trim();
    if (v.isEmpty) return;
    final cmd = "MOVE:$v";
    await sendCommand(cmd);
    _distanceController.clear();
  }

  Future<void> _toggleLineMode() async {
    if (lineModeActive) await sendCommand("0");
    else await sendCommand("T");
  }

  Future<void> _deliver() async => sendCommand("D");
  Future<void> _interact() async => sendCommand("I");
  Future<void> _callRex() async => sendCommand("REX");
  
  Future<void> _onAiSubmit() async {
    final text = _aiController.text.trim();
    if (text.isEmpty) return;
    _addLog("🧠 User input: $text");
    final mapping = _mapTextToCommand(text);
    if (mapping != null) {
      _addLog("↪️ Mapped to: ${mapping.replaceAll('\n', '\\n')}");
      await sendCommand(mapping);
    } else {
      _addLog("❓ Could not map command automatically: sending as 'I'");
      await sendCommand("I");
    }
    _aiController.clear();
  }

  Future<void> _disconnect() async {
    try {
      await widget.connection?.finish();
    } catch (_) {}
    _setDisconnected();
  }

  // --- UI WIDGET COMPONENTS ---

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10), // Consistent Gap: 10dp
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _statusTile(IconData icon, String title, String value, {Color? color}) {
    color ??= Colors.black87;
    return Row(children: [
      CircleAvatar(radius: 18, backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color, size: 18)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);
  }

  Widget _animatedControlButton(String id, IconData icon, String label, Color color, VoidCallback onTap) {
    final pressed = _pressedButton == id;
    final bool isStop = id == 'S';
    final contentColor = isStop ? Colors.redAccent : color;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: pressed
            ? [BoxShadow(color: contentColor.withOpacity(0.28), blurRadius: 10, offset: const Offset(0, 6))]
            : [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: pressed ? contentColor.withOpacity(0.12) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          onHighlightChanged: (v) => setState(() => _pressedButton = v ? id : (_pressedButton == id ? "" : _pressedButton)),
          child: SizedBox(
            height: 64, // equal height for all grid buttons
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: pressed ? contentColor : (isStop ? Colors.red : Colors.black54)),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 13, color: pressed ? contentColor : (isStop ? Colors.red : Colors.black87), fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool narrow = MediaQuery.of(context).size.width < 360;
    
    return FadeTransition(
      opacity: _pageFade,
      child: SlideTransition(
        position: _pageSlide,
        child: ScaleTransition(
          scale: _exitScale.drive(Tween(begin: 1.0, end: 1.0)),
          child: AnimatedBuilder(
            animation: _exitController,
            builder: (context, child) => Opacity(opacity: 1.0 - _exitFade.value, child: child),
            child: Scaffold(
              backgroundColor: const Color(0xFFF0F4F8), // neutral light bg
              appBar: AppBar(
                elevation: 2,
                backgroundColor: Colors.blue.shade700,
                leading: IconButton(
                  icon: const Icon(Icons.more_vert),
                  tooltip: "Connect Device",
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const RexUniversalBluetooth()));
                  },
                ),
                title: Row(children: [
                  Expanded(child: Text(widget.device?.name ?? "REX Controller", style: const TextStyle(fontWeight: FontWeight.w600))),
                  const SizedBox(width: 6),
                  Icon(isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled, color: isConnected ? Colors.greenAccent : Colors.redAccent, size: 18),
                  const SizedBox(width: 6),
                  Text(isConnected ? "Connected" : "Offline", style: TextStyle(color: isConnected ? Colors.greenAccent : Colors.redAccent, fontSize: 14)),
                ]),
                actions: [
                  if (widget.connection != null)
                    IconButton(tooltip: "Disconnect", onPressed: _disconnect, icon: const Icon(Icons.power_settings_new)),
                ],
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // TIP BUBBLE
                    if (widget.connection == null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(10)),
                        child: Row(children: const [
                          Icon(Icons.info, color: Colors.deepOrange),
                          SizedBox(width: 10),
                          Expanded(child: Text("Not connected to REX. Tap the 3 dots menu on the top-left to connect.", style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold))),
                        ]),
                      ),

                    // STATUS PANEL
                    _buildCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          const Text("Status Panel", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: isConnected ? Colors.green.shade600 : Colors.red.shade400, borderRadius: BorderRadius.circular(22)),
                            child: Row(children: [
                              Icon(isConnected ? Icons.check_circle : Icons.error, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(isConnected ? "Connected" : "Offline", style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: _statusTile(Icons.task_alt, "Robot State", robotState)),
                          const SizedBox(width: 10),
                          Expanded(child: _statusTile(Icons.place, "Cabin", currentCabin)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _statusTile(Icons.straighten, "Distance", "${distanceMeters.toStringAsFixed(2)} m")),
                          const SizedBox(width: 10),
                          Expanded(child: _statusTile(obstacle ? Icons.warning : Icons.check_circle, "Obstacle", obstacle ? "Detected" : "Clear", color: obstacle ? Colors.red : Colors.green)),
                        ]),
                        if (lastError.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Text("Error: $lastError", style: const TextStyle(color: Colors.redAccent))),
                        ],
                      ]),
                    ),

                    // CONTROL PANEL
                    _buildCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        const Text("Control Panel", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 14),
                        
                        // 3x3 GRID D-PAD
                        Column(children: [
                          Row(children: [
                            const Expanded(child: SizedBox()),
                            const SizedBox(width: 10),
                            Expanded(child: _animatedControlButton("F", Icons.arrow_upward, "Forward", Colors.blue, () => _onControlTap("F"))),
                            const SizedBox(width: 10),
                            const Expanded(child: SizedBox()),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(child: _animatedControlButton("L", Icons.arrow_back, "Left", Colors.orange, () => _onControlTap("L"))),
                            const SizedBox(width: 10),
                            Expanded(child: _animatedControlButton("S", Icons.stop, "Stop", Colors.red, () => _onControlTap("S"))),
                            const SizedBox(width: 10),
                            Expanded(child: _animatedControlButton("R", Icons.arrow_forward, "Right", Colors.orange, () => _onControlTap("R"))),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            const Expanded(child: SizedBox()),
                            const SizedBox(width: 10),
                            Expanded(child: _animatedControlButton("B", Icons.arrow_downward, "Backward", Colors.blue, () => _onControlTap("B"))),
                            const SizedBox(width: 10),
                            const Expanded(child: SizedBox()),
                          ]),
                        ]),

                        const SizedBox(height: 18),

                        // DISTANCE & CALL/PING
                        Row(children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _distanceController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.straighten), 
                                hintText: "Distance (m)", 
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.deepPurple,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: _sendMoveMeters,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(width: 48, height: 48, alignment: Alignment.center, child: const Icon(Icons.send, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: OutlinedButton(onPressed: _callRex, style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(0, 48)), child: const Text("Call"))),
                          const SizedBox(width: 8),
                          Expanded(child: OutlinedButton(onPressed: () => sendCommand("REX"), style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), minimumSize: const Size(0, 48)), child: const Text("Ping"))),
                        ]),

                        const SizedBox(height: 14),

                        // 3 EQUAL MODE BUTTONS
                        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _deliver, 
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.zero, minimumSize: const Size(0, 56)), 
                              child: const Text("Deliver", style: TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center, overflow: TextOverflow.visible, softWrap: false)
                            )
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _toggleLineMode, 
                              style: ElevatedButton.styleFrom(backgroundColor: lineModeActive ? Colors.orange : Colors.grey.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.zero, minimumSize: const Size(0, 56)), 
                              child: Text(lineModeActive ? "Stop Line" : "Line Follow", style: const TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center, overflow: TextOverflow.visible, softWrap: false)
                            )
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                               onPressed: _interact, 
                               style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: EdgeInsets.zero, minimumSize: const Size(0, 56)), 
                               child: const Text("Interact", style: TextStyle(color: Colors.white, fontSize: 12), textAlign: TextAlign.center, overflow: TextOverflow.visible, softWrap: false)
                            )
                          ),
                        ]),
                      ]),
                    ),

                    // AI / VOICE COMMAND ROW
                    _buildCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("AI / Voice Command", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: _aiController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.chat_bubble_outline), 
                                hintText: "e.g. Move 2 meters", 
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))
                              ),
                              onSubmitted: (_) => _onAiSubmit(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Material(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: _onAiSubmit,
                              borderRadius: BorderRadius.circular(10),
                              child: Container(width: 48, height: 48, alignment: Alignment.center, child: const Icon(Icons.send, color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Material(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () {
                                _addLog("🎤 Voice pressed (STT not enabled)");
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Voice: STT not implemented here")));
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(width: 48, height: 48, alignment: Alignment.center, child: const Icon(Icons.mic, color: Colors.white)),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        const Text("Tip: use natural phrases. App maps them to REX commands.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ]),
                    ),

                    // ACTION LOG
                    _buildCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text("Action Log", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 140,
                          child: logs.isEmpty ? const Center(child: Text("No actions yet", style: TextStyle(color: Colors.grey))) : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: logs.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final txt = logs[i];
                              bool isWarning = txt.contains("⚠️") || txt.contains("❌");
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isWarning) const Padding(padding: EdgeInsets.only(right: 6, top: 1), child: Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange)),
                                  Expanded(child: Text(isWarning ? txt.replaceAll("⚠️ ", "").replaceAll("❌ ", "") : txt, style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: isWarning ? Colors.deepOrange : Colors.black87))),
                                ],
                              );
                            },
                          ),
                        ),
                      ]),
                    ),
                    
                    // EMERGENCY STOP BUTTON - AT BOTTOM
                    Container(
                      width: double.infinity,
                      height: 56,
                      margin: const EdgeInsets.only(top: 10),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          _addLog("🛑 Emergency pressed");
                          await sendCommand("S");
                        },
                        icon: const Icon(Icons.dangerous, color: Colors.white),
                        label: const Text("EMERGENCY STOP", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF44336),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
