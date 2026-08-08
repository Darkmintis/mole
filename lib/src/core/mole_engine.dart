import '../config/mole_config.dart';
import '../sources/mole_source.dart';
import 'mole_store.dart';

/// Storage inspection pipeline: registers sources into the [MoleStore] and
/// exposes the read/write mutations used by the UI.
class MoleEngine {
  MoleEngine({required MoleStore store, required MoleConfig config})
    : _store = store,
      _config = config;

  final MoleStore _store;
  MoleConfig _config;

  MoleConfig get config => _config;

  MoleStore get store => _store;

  void updateConfig(MoleConfig config) {
    _config = config;
  }

  /// Wires all [sources] into the store and lets them start pushing data.
  void attach(Iterable<MoleSource> sources) {
    for (final source in sources) {
      _store.addSource(source);
    }
  }

  /// Detaches every registered source.
  void detachAll() {
    for (final source in List<MoleSource>.of(_store.sources)) {
      _store.removeSource(source);
    }
  }

  List<MoleDataEntry> entriesOf(MoleSource source) => _store.entriesOf(source);

  int countOf(MoleSource source) => _store.countOf(source);

  Future<void> setValue(MoleSource source, String key, dynamic value) =>
      _store.setValue(source, key, value);

  Future<void> deleteValue(MoleSource source, String key) =>
      _store.deleteValue(source, key);

  Future<void> clearSource(MoleSource source) => _store.clearSource(source);

  Future<void> clearAll() => _store.clearAll();
}