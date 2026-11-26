import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:marionette_flutter/src/binding/extensions/agent_connection_extensions.dart';
import 'package:marionette_flutter/src/binding/marionette_extension_result.dart';
import 'package:marionette_flutter/src/services/agent_connection_service.dart';

/// Params reach an extension callback as `Map<String, String>`, so these
/// tests speak the wire shape, not Dart types.
void main() {
  group('AgentConnectionService', () {
    test('starts disconnected', () {
      final service = AgentConnectionService();
      addTearDown(service.dispose);

      expect(service.connected.value, isFalse);
    });

    test('reads as disconnected once the lease runs out', () {
      fakeAsync((async) {
        final service = AgentConnectionService()
          ..markConnected(lease: const Duration(seconds: 30));

        async.elapse(const Duration(seconds: 29));
        expect(service.connected.value, isTrue);

        async.elapse(const Duration(seconds: 1));
        expect(service.connected.value, isFalse);

        service.dispose();
      });
    });

    test('a renewal restarts the lease', () {
      fakeAsync((async) {
        final service = AgentConnectionService()
          ..markConnected(lease: const Duration(seconds: 30));

        async.elapse(const Duration(seconds: 20));
        service.markConnected(lease: const Duration(seconds: 30));
        async.elapse(const Duration(seconds: 20));

        expect(service.connected.value, isTrue);

        async.elapse(const Duration(seconds: 10));
        expect(service.connected.value, isFalse);

        service.dispose();
      });
    });

    test('a disconnect cancels the lease', () {
      fakeAsync((async) {
        final service = AgentConnectionService()
          ..markConnected(lease: const Duration(seconds: 30))
          ..markDisconnected();

        expect(service.connected.value, isFalse);
        expect(async.pendingTimers, isEmpty);

        service.dispose();
      });
    });

    test('notifies only on a change', () {
      final service = AgentConnectionService();
      addTearDown(service.dispose);
      var notifications = 0;
      service.connected.addListener(() => notifications++);

      service
        ..markConnected(lease: const Duration(seconds: 30))
        ..markConnected(lease: const Duration(seconds: 30))
        ..markDisconnected()
        ..markDisconnected();

      expect(notifications, 2);
    });
  });

  group('setAgentConnected', () {
    late AgentConnectionService service;

    setUp(() => service = AgentConnectionService());
    tearDown(() => service.dispose());

    String invalidParamsDetail(MarionetteExtensionResult result) {
      expect(result, isA<MarionetteExtensionInvalidParams>());
      return (result as MarionetteExtensionInvalidParams).detail;
    }

    test('connects and reports the new state', () {
      final result = setAgentConnected({'connected': 'true'}, service);

      expect(result, isA<MarionetteExtensionSuccess>());
      expect((result as MarionetteExtensionSuccess).data, {'connected': true});
      expect(service.connected.value, isTrue);
    });

    test('uses the default lease when leaseMs is omitted', () {
      fakeAsync((async) {
        final service = AgentConnectionService();
        setAgentConnected({'connected': 'true'}, service);

        async.elapse(
          defaultAgentConnectionLease - const Duration(milliseconds: 1),
        );
        expect(service.connected.value, isTrue);

        async.elapse(const Duration(milliseconds: 1));
        expect(service.connected.value, isFalse);

        service.dispose();
      });
    });

    test('honors leaseMs', () {
      fakeAsync((async) {
        final service = AgentConnectionService();
        setAgentConnected({'connected': 'true', 'leaseMs': '500'}, service);

        async.elapse(const Duration(milliseconds: 500));
        expect(service.connected.value, isFalse);

        service.dispose();
      });
    });

    test('disconnects', () {
      setAgentConnected({'connected': 'true'}, service);

      final result = setAgentConnected({'connected': 'false'}, service);

      expect((result as MarionetteExtensionSuccess).data, {'connected': false});
      expect(service.connected.value, isFalse);
    });

    test('requires connected', () {
      expect(
        invalidParamsDetail(setAgentConnected(const {}, service)),
        contains('"connected" is required'),
      );
    });

    test('rejects a connected value that is not a boolean', () {
      expect(
        invalidParamsDetail(setAgentConnected({'connected': 'yes'}, service)),
        contains('"connected"'),
      );
    });

    test('rejects a lease that is not a positive number', () {
      for (final leaseMs in ['0', '-1', 'soon']) {
        expect(
          invalidParamsDetail(
            setAgentConnected(
              {'connected': 'true', 'leaseMs': leaseMs},
              service,
            ),
          ),
          contains('"leaseMs"'),
        );
      }
      expect(service.connected.value, isFalse);
    });
  });
}
