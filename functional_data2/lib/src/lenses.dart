import 'package:built_collection/built_collection.dart';
import 'package:meta/meta.dart';
import 'package:plain_optional/plain_optional.dart';

/// Get the value of a field of type [T] of [subject]
typedef Getter<S, T> = T Function(S subject);

/// Returns a copy of [subject] but with a field of type [T] replaced by [value]
typedef Updater<S, T> = S Function(S subject, T value);

@immutable
class Lens<S, T> {
  final Getter<S, T> get;
  final Updater<S, T> update;

  const Lens(this.get, this.update);

  /// Chain two lenses together.
  ///
  /// For example, `FooLens.bar.then(BarLens.name).get(foo)`, is equivalent to `foo.bar.name`.
  Lens<S, Q> then<Q>(Lens<T, Q> lens) => Lens<S, Q>(
        (s) => lens.get(get(s)),
        (s, q) => update(s, lens.update(get(s), q)),
      );

  /// Chain two lenses together.
  ///
  /// Example:
  /// ```dart
  ///  final bar = Bar(foos: [Foo(number: 101, name: "One"), Foo(number: 102, name: "Two")], driver: "One");
  ///
  ///  final driversNumber =
  ///      Bar$.foos.thenWithContext((bar) => List$.where<Foo>((foo) => foo.name == bar.driver).then(Foo$.number));
  ///  print(driversNumber.of(bar).value);
  ///  // 101
  /// ```
  Lens<S, Q> thenWithContext<Q>(Lens<T, Q> Function(S context) lensMaker) =>
      Lens<S, Q>(
        (s) => lensMaker(s).get(get(s)),
        (s, q) => update(s, lensMaker(s).update(get(s), q)),
      );

  /// Return a copy of [s] where the field of this lenses focus has been transformed by applying [f]
  S map(T Function(T) f, S s) => update(s, f(get(s)));

  /// The same as [then] but not type safe.
  Lens<S, dynamic> operator >>(Lens<T, dynamic> lens) => then(lens);

  /// Focus this lens on a specific instance of [S]
  FocusedLens<S, T> of(S s) => FocusedLens<S, T>._(s, this);
}

/// A lenses that has been focused on (bound to) a specific instance of the subject.
///
/// Create an instance by using [Lens.of] on a subject.
@immutable
class FocusedLens<S, T> {
  final S _subject;
  final Lens<S, T> _lens;

  const FocusedLens._(this._subject, this._lens);

  /// Chain two lenses together.
  ///
  /// For example, `FooLens.bar.of(foo).then(BarLens.name)`, is equivalent to `foo.bar.name`.
  FocusedLens<S, Q> then<Q>(Lens<T, Q> lens) =>
      FocusedLens<S, Q>._(_subject, _lens.then(lens));

  /// Chain two lenses together.
  ///
  /// Example:
  /// ```dart
  ///  final bar = Bar(foos: [Foo(number: 101, name: "One"), Foo(number: 102, name: "Two")], driver: "One");
  ///
  ///  final driversNumber =
  ///      Bar$.foos.of(bar).thenWithContext((bar) => List$.where<Foo>((foo) => foo.name == bar.driver).then(Foo$.number));
  ///  print(driversNumber.value);
  ///  // 101
  /// ```
  FocusedLens<S, Q> thenWithContext<Q>(
          Lens<T, Q> Function(S context) lensMaker) =>
      FocusedLens<S, Q>._(_subject, _lens.thenWithContext(lensMaker));

  /// The value to lens is focused on
  T get value => _lens.get(_subject);

  /// Returns a copy of the subject this lens is focused on with the field of this lens change to [t]
  S update(T t) => _lens.update(_subject, t);

  /// Returns a copy of the subject this lens is focused on with the field of this lens transformed by [f]
  S map(T Function(T) f) => update(f(value));
}

class List$ {
  List$._();

  static Lens<List<T>, T> atIndex<T>(int i) => Lens<List<T>, T>(
        (s) => s[i],
        (s, t) {
          assert(i >= 0 && i < s.length);
          final newS = List<T>.from(s);
          newS.replaceRange(i, i + 1, [t]);
          return newS;
        },
      );

  static Lens<List<T>, T> first<T>() => atIndex(0);

  static Lens<List<T>, T> where<T>(bool Function(T) predicate) =>
      Lens<List<T>, T>(
        (s) => s.firstWhere(predicate),
        (s, t) {
          final index = s.indexWhere(predicate);
          final newS = List<T>.from(s);
          newS.replaceRange(index, index + 1, [t]);
          return newS;
        },
      );

  static Lens<List<T>, Optional<T>> whereOptional<T>(
          bool Function(T) predicate) =>
      Lens<List<T>, Optional<T>>(
        (s) => Optional<T>(s.firstWhere(predicate, orElse: () => null)),
        (s, t) {
          if (!t.hasValue) return s;
          final index = s.indexWhere(predicate);
          if (index < 0) return s;
          final newS = List<T>.from(s);
          newS.replaceRange(index, index + 1, [t.unsafe]);
          return newS;
        },
      );
}

class Map$ {
  Map$._();

  static Lens<Map<S, T>, Optional<T>> atKey<S, T>(S i) =>
      Lens<Map<S, T>, Optional<T>>(
        (s) => s.containsKey(i) ? Optional(s[i]) : Optional.none(),
        (s, t) => t
            .map((tVal) => Map.from(s)..addEntries([MapEntry(i, tVal)]))
            .valueOr(() => s),
      );

  static Lens<Map<S, T>, MapEntry<S, T>> where<S, T>(
          bool Function(MapEntry<S, T>) predicate) =>
      Lens<Map<S, T>, MapEntry<S, T>>(
        (s) => s.entries.firstWhere(predicate),
        (s, t) {
          var entriesList = s.entries.toList();
          final index = entriesList.indexWhere(predicate);
          final newS = List<MapEntry<S, T>>.from(entriesList);
          if (predicate(entriesList[index]))
            newS.replaceRange(index, index + 1, []);
          return Map.fromEntries(newS);
        },
      );

  static Lens<Map<S, T>, Optional<MapEntry<S, T>>> whereOptional<S, T>(
          bool Function(MapEntry<S, T>) predicate) =>
      Lens<Map<S, T>, Optional<MapEntry<S, T>>>(
        (s) => Optional((s.entries).firstWhere(predicate, orElse: () => null)),
        (s, t) {
          if (!t.hasValue) return s;
          final index = s.entries.toList().indexWhere(predicate);
          if (index < 0) return s;
          final newS = Map<S, T>.from(s);
          newS.entries.toList().replaceRange(index, index + 1, [t.unsafe]);
          return newS;
        },
      );
}

class BuiltMap$ {
  BuiltMap$._();

  static Lens<BuiltMap<S, T>, Optional<T>> atKey<S, T>(S i) =>
      Lens<BuiltMap<S, T>, Optional<T>>(
        (s) => s.containsKey(i) ? Optional(s[i]) : Optional.none(),
        (s, t) {
          return t
              .map((tVal) =>
                  (s.toBuilder()..addEntries([MapEntry(i, tVal)])).build())
              .valueOr(() => s);
        },
      );

  static Lens<BuiltMap<S, T>, MapEntry<S, T>> where<S, T>(
          bool Function(MapEntry<S, T>) predicate) =>
      Lens<BuiltMap<S, T>, MapEntry<S, T>>(
        (s) => s.entries.firstWhere(predicate),
        (s, t) {
          var entriesList = s.entries.toList();
          final index = entriesList.indexWhere(predicate);
          final newS = List<MapEntry<S, T>>.from(entriesList);
          if (predicate(entriesList[index]))
            newS.replaceRange(index, index + 1, []);
          return BuiltMap.from(Map.fromEntries(newS));
        },
      );
}

extension DeprecatedOptional<T> on Optional<T> {
  @Deprecated("Use `unsafe` instead")
  T get raw => unsafe;
}
