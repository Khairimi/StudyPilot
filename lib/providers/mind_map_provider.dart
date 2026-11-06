import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:study_app/database/user_session.dart';
import 'package:study_app/models/mind_map.dart';

class MindMapProvider extends ChangeNotifier implements UserScopedState {
  /// Active user's box, or null when signed out (operations become no-ops).
  Box<MindMap>? get _mindMapsBox => HiveService.activeOrNull?.mindMaps;

  @override
  void clearUserState() => notifyListeners();

  @override
  Future<void> loadUserState(String uid) async => notifyListeners();

  List<MindMap> get mindMaps => _mindMapsBox?.values.toList() ?? [];

  List<MindMap> getMindMapsForContext(String? subjectId, String? chapterId) {
    final box = _mindMapsBox;
    if (box == null) return [];
    if (subjectId == 'general') {
      return box.values.where((mm) => mm.subjectId == 'general').toList();
    }
    return box.values.where((mm) => mm.subjectId == subjectId && mm.chapterId == chapterId).toList();
  }

  Future<void> addMindMap(String title, String? subjectId, String? chapterId) async {
    final box = _mindMapsBox;
    if (box == null) return;
    final mm = MindMap(title: title, subjectId: subjectId, chapterId: chapterId);
    await box.put(mm.id, mm);
    notifyListeners();
  }

  Future<void> updateMindMapNode(String mapId, MindMapNode node) async {
    final map = _mindMapsBox?.get(mapId);
    if (map != null) {
      final idx = map.nodes.indexWhere((n) => n.id == node.id);
      if (idx != -1) {
        map.nodes[idx] = node;
      } else {
        map.nodes.add(node);
      }
      await map.save();
      notifyListeners();
    }
  }

  Future<void> deleteMindMapNode(String mapId, String nodeId) async {
    final map = _mindMapsBox?.get(mapId);
    if (map != null) {
      map.nodes.removeWhere((n) => n.id == nodeId);
      await map.save();
      notifyListeners();
    }
  }

  Future<void> deleteMindMap(String id) async {
    final box = _mindMapsBox;
    if (box == null) return;
    await box.delete(id);
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }
}
