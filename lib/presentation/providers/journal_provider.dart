import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_flow/domain/models/journal_model.dart';
import 'package:habit_flow/data/repositories/journal_repository.dart';

// 1. Repository ka provider
final journalRepositoryProvider = Provider<JournalRepository>((ref) {
  return JournalRepository();
});

// 2. State Notifier 
class JournalNotifier extends StateNotifier<List<JournalModel>> {
  final JournalRepository _repository;

  JournalNotifier(this._repository) : super([]) {
    loadJournals(); // App/Tab khulte hi data apne aap fetch hoga
  }

  Future<void> loadJournals() async {
    final journals = await _repository.getAllJournals();
    state = journals; 
  }

  Future<void> addJournal(JournalModel journal) async {
    await _repository.addJournal(journal);
    await loadJournals();
  }

  Future<void> updateJournal(JournalModel journal) async {
    await _repository.updateJournal(journal);
    await loadJournals();
  }

  Future<void> deleteJournal(String id) async {
    await _repository.deleteJournal(id);
    await loadJournals();
  }
}

// 3. Main Provider jisko humari Journal Screen use karegi
final journalProvider = StateNotifierProvider<JournalNotifier, List<JournalModel>>((ref) {
  final repository = ref.read(journalRepositoryProvider);
  return JournalNotifier(repository);
});