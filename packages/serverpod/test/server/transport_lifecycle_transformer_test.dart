import 'dart:async';

import 'package:serverpod/src/server/server.dart';
import 'package:test/test.dart';

void main() {
  group('createTransportLifecycleTransformer', () {
    test(
      'when the source stream closes normally '
      'then onTerminate is invoked once with null error and null stackTrace',
      () async {
        final controller = StreamController<int>();
        Object? capturedError = _unset;
        StackTrace? capturedStackTrace = StackTrace.empty;
        var terminateCount = 0;

        final transformed = controller.stream.transform(
          createTransportLifecycleTransformer<int>(
            onTerminate: (error, stackTrace) {
              terminateCount++;
              capturedError = error;
              capturedStackTrace = stackTrace;
            },
          ),
        );

        final received = <int>[];
        final sub = transformed.listen(received.add);

        controller.add(1);
        controller.add(2);
        await controller.close();
        await sub.cancel();

        expect(received, equals([1, 2]));
        expect(terminateCount, equals(1));
        expect(capturedError, isNull);
        expect(capturedStackTrace, isNull);
      },
    );

    test(
      'when the source stream emits an error '
      'then onTerminate is invoked with the error and the error is forwarded',
      () async {
        final controller = StreamController<int>();
        Object? capturedError;
        StackTrace? capturedStackTrace;
        var terminateCount = 0;

        final transformed = controller.stream.transform(
          createTransportLifecycleTransformer<int>(
            onTerminate: (error, stackTrace) {
              terminateCount++;
              capturedError = error;
              capturedStackTrace = stackTrace;
            },
          ),
        );

        Object? receivedError;
        final sub = transformed.listen(
          (_) {},
          onError: (Object error, StackTrace st) {
            receivedError = error;
          },
        );

        final injectedError = StateError('boom');
        final injectedStack = StackTrace.current;
        controller.addError(injectedError, injectedStack);
        await Future<void>.delayed(Duration.zero);
        await controller.close();
        await sub.cancel();

        expect(terminateCount, equals(1));
        expect(capturedError, same(injectedError));
        expect(capturedStackTrace, same(injectedStack));
        expect(receivedError, same(injectedError));
      },
    );

    test(
      'when the source stream errors and then closes '
      'then onTerminate is only invoked once (idempotent)',
      () async {
        final controller = StreamController<int>();
        var terminateCount = 0;

        final transformed = controller.stream.transform(
          createTransportLifecycleTransformer<int>(
            onTerminate: (_, _) => terminateCount++,
          ),
        );

        final sub = transformed.listen(
          (_) {},
          onError: (Object _, StackTrace _) {},
        );

        controller.addError(StateError('boom'));
        await Future<void>.delayed(Duration.zero);
        await controller.close();
        await sub.cancel();

        expect(terminateCount, equals(1));
      },
    );

    test(
      'when data events arrive before termination '
      'then each data event is forwarded unchanged',
      () async {
        final controller = StreamController<String>();
        final transformed = controller.stream.transform(
          createTransportLifecycleTransformer<String>(
            onTerminate: (_, _) {},
          ),
        );

        final received = <String>[];
        final sub = transformed.listen(received.add);

        controller.add('a');
        controller.add('b');
        controller.add('c');
        await controller.close();
        await sub.cancel();

        expect(received, equals(['a', 'b', 'c']));
      },
    );
  });
}

/// Sentinel used to distinguish between "onTerminate was never called" and
/// "onTerminate was called with a null error".
const Object _unset = Object();
