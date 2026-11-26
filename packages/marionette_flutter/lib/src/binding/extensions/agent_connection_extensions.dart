import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/src/binding/extensions/extension_helpers.dart';
import 'package:marionette_flutter/src/binding/marionette_extension_result.dart';
import 'package:marionette_flutter/src/binding/register_extension_internal.dart';
import 'package:marionette_flutter/src/services/agent_connection_service.dart';

/// How long a `connected: true` report holds when the caller gives no
/// `leaseMs`.
const defaultAgentConnectionLease = Duration(seconds: 30);

/// Registers the agent-connection `marionette.*` extension:
/// setAgentConnected.
void registerAgentConnectionExtensions({
  required AgentConnectionService agentConnectionService,
}) {
  registerInternalMarionetteExtension(
    name: 'marionette.setAgentConnected',
    callback: (params) async =>
        setAgentConnected(params, agentConnectionService),
  );
}

/// Handles a `marionette.setAgentConnected` call.
///
/// Params:
/// - `connected` (required): `true` when a client connects or renews its
///   lease, `false` when it disconnects.
/// - `leaseMs` (optional, positive): how long a `connected: true` report
///   holds before it reads as a disconnect. Defaults to
///   [defaultAgentConnectionLease]. Ignored with `connected: false`.
///
/// Extracted from the callback so every validation branch can be exercised
/// without a VM service.
@visibleForTesting
MarionetteExtensionResult setAgentConnected(
  Map<String, String> params,
  AgentConnectionService service,
) {
  final connected = parseOptionalBool(params, 'connected');
  if (connected.error case final error?) {
    return error;
  }

  if (connected.value == null) {
    return MarionetteExtensionResult.invalidParams(
      'Parameter "connected" is required',
    );
  }

  final lease = parseDurationMs(
    params,
    'leaseMs',
    defaultValue: defaultAgentConnectionLease,
    requirePositive: true,
  );
  if (lease.error case final error?) {
    return error;
  }

  if (connected.value!) {
    service.markConnected(lease: lease.duration!);
  } else {
    service.markDisconnected();
  }

  return MarionetteExtensionResult.success({
    'connected': service.connected.value,
  });
}
