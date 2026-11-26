import 'dart:async';

import 'package:flutter/foundation.dart';

/// Tracks whether a Marionette client (the MCP server or the CLI) is
/// connected to the app.
///
/// The app cannot see a VM service connection open or close, so the client
/// reports it: `marionette.setAgentConnected` with `connected: true` and a
/// lease when it connects, the same call again before the lease runs out
/// while it stays connected, and `connected: false` when it disconnects.
///
/// A lease that runs out without a renewal reads as a disconnect. That covers
/// a client that went away without saying so: a killed MCP server, a dropped
/// USB cable, or a device that went to sleep.
///
/// The app reads the state through [connected], for example to show a
/// screensaver only while no agent is watching.
class AgentConnectionService {
  final ValueNotifier<bool> _connected = ValueNotifier(false);

  Timer? _leaseTimer;

  /// Whether a client is connected now. Starts `false`.
  ValueListenable<bool> get connected => _connected;

  /// Records a connected client whose connection is valid for [lease], or
  /// renews the lease of one that is already connected.
  void markConnected({required Duration lease}) {
    _leaseTimer?.cancel();
    _leaseTimer = Timer(lease, markDisconnected);
    _connected.value = true;
  }

  /// Records that the client disconnected, or that its lease ran out.
  void markDisconnected() {
    _leaseTimer?.cancel();
    _leaseTimer = null;
    _connected.value = false;
  }

  /// Cancels the lease timer and releases the listenable.
  @visibleForTesting
  void dispose() {
    _leaseTimer?.cancel();
    _connected.dispose();
  }
}
