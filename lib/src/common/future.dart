part of plugins.common;

/**
 * Allows for the callback of [then] to be optionally called if
 * [callIf] returns true.
 */
class ConditionalFuture<T> implements Future<T> {

  Future _future;
  Function _condition = (T) => true;

  /**
   * Creates a [ConditionalFuture] from a pre-existing [Future].
   */
  factory ConditionalFuture.from(Future future) {
    var cf = new ConditionalFuture(() => null);
    cf._future = future;
    return cf;
  }

  ConditionalFuture(computation()) {
    _future = new Future(computation);
  }

  /**
   * If [condition] returns true then [then] will be called when the [Future]
   * obtains its value.
   */
  ConditionalFuture callIf(bool condition(T)) {
    _condition = condition;
    return this;
  }

  /**
   * If [callIf] returns true then [onValue] will be called. [onError] will be
   * called regardless if an error occurs during the computation.
   */
  @override
  Future then(onValue(T value), { Function onError }) {
    return _future.then((T value) {
      if (_condition(value)) {
        onValue(value);
      }
    }, onError: onError);
  }

  @override
  Future<T> whenComplete(action()) {
    return _future.whenComplete(action);
  }

  @override
  Future timeout(Duration timeLimit, {onTimeout()}) {
    return _future.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Future catchError(Function onError, {bool test(Object error)}) {
    return _future.catchError(onError, test: test);
  }

  @override
  Stream<T> asStream() {
    return _future.asStream();
  }
}

class ConditionalCompleter<T> implements Completer<T> {

  Completer _completer = new Completer();
  ConditionalFuture _cf;

  @override
  ConditionalFuture get future {
    if (_cf != null) return _cf;
    return _cf = new ConditionalFuture.from(_completer.future);
  }

  @override
  bool get isCompleted => _completer.isCompleted;

  @override
  void complete([value]) {
    _completer.complete(value);
  }

  @override
  void completeError(Object error, [StackTrace stackTrace]) {
    _completer.completeError(error, stackTrace);
  }
}
