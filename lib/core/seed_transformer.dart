import 'dart:async';

/// StreamTransformer that prepends a seed value (computed lazily on listen)
/// before forwarding all subsequent events from the source stream.
class SeedTransformer<T> extends StreamTransformerBase<T, T> {
  SeedTransformer(this._seedFactory);

  final T Function() _seedFactory;

  @override
  Stream<T> bind(Stream<T> stream) {
    late StreamController<T> controller;
    StreamSubscription<T>? subscription;

    controller = StreamController<T>.broadcast(
      onListen: () {
        controller.add(_seedFactory());
        subscription = stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () {
        unawaited(subscription?.cancel());
      },
    );

    return controller.stream;
  }
}
