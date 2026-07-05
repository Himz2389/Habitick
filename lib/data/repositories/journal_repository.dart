import 'package:habit_flow/data/local/database_helper.dart';
import 'package:habit_flow/domain/models/journal_model.dart';

class JournalRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Saare journals lana aur unhe Model mein convert karna
  Future<List<JournalModel>> getAllJournals() async {
    final List<Map<String, dynamic>> maps = await _dbHelper.getJournals();
    return maps.map((map) => JournalModel.fromMap(map)).toList();
  }

  // Naya journal save karna
  Future<int> addJournal(JournalModel journal) async {
    return await _dbHelper.insertJournal(journal.toMap());
  }

  // Purana journal update karna
  Future<int> updateJournal(JournalModel journal) async {
    return await _dbHelper.updateJournal(journal.toMap());
  }

  // Journal delete karna
  Future<int> deleteJournal(String id) async {
    return await _dbHelper.deleteJournal(id);
  }
}