import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:study_app/database/user_session.dart';
import 'package:study_app/models/todo.dart';
import 'package:study_app/models/todo_subtask.dart';

class TodoProvider extends ChangeNotifier implements UserScopedState {
  /// Active user's box, or null when signed out (operations become no-ops).
  Box<Todo>? get _todosBox => HiveService.activeOrNull?.todos;

  @override
  void clearUserState() => notifyListeners();

  @override
  Future<void> loadUserState(String uid) async => notifyListeners();

  List<Todo> get todos => _todosBox?.values.toList() ?? [];

  List<Todo> getTodosForContext(String? subjectId, String? chapterId) {
    final box = _todosBox;
    if (box == null) return [];
    if (subjectId == 'general') {
      return box.values.where((todo) => todo.subjectId == 'general').toList();
    }
    return box.values.where((todo) => todo.subjectId == subjectId && todo.chapterId == chapterId).toList();
  }

  Future<void> addTodo(String task, String? subjectId, String? chapterId) async {
    final box = _todosBox;
    if (box == null) return;
    final todo = Todo(task: task, subjectId: subjectId, chapterId: chapterId);
    await box.put(todo.id, todo);
    notifyListeners();
  }

  Future<void> toggleTodo(String id) async {
    final todo = _todosBox?.get(id);
    if (todo != null) {
      todo.isCompleted = !todo.isCompleted;
      await todo.save();
      notifyListeners();
    }
  }

  Future<void> toggleReminder(String id) async {
    final todo = _todosBox?.get(id);
    if (todo != null) {
      todo.reminder = !todo.reminder;
      await todo.save();
      notifyListeners();
    }
  }

  Future<void> deleteTodo(String id) async {
    final todo = _todosBox?.get(id);
    if (todo != null) {
      await todo.delete();
      notifyListeners();
    }
  }

  Future<void> updateTodo(String id, String newTask) async {
    final todo = _todosBox?.get(id);
    if (todo != null) {
      todo.task = newTask;
      await todo.save();
      notifyListeners();
    }
  }

  // Sub-task methods
  Future<void> addSubTask(String todoId, String task) async {
    final todo = _todosBox?.get(todoId);
    if (todo != null) {
      todo.subTasks.add(TodoSubTask(task: task));
      await todo.save();
      notifyListeners();
    }
  }

  Future<void> toggleSubTask(String todoId, String subTaskId) async {
    final todo = _todosBox?.get(todoId);
    if (todo != null) {
      final subTask = todo.subTasks.firstWhere((st) => st.id == subTaskId);
      subTask.isCompleted = !subTask.isCompleted;
      await todo.save();
      notifyListeners();
    }
  }

  Future<void> deleteSubTask(String todoId, String subTaskId) async {
    final todo = _todosBox?.get(todoId);
    if (todo != null) {
      todo.subTasks.removeWhere((st) => st.id == subTaskId);
      await todo.save();
      notifyListeners();
    }
  }

  Future<void> updateSubTask(String todoId, String subTaskId, String newTask) async {
    final todo = _todosBox?.get(todoId);
    if (todo != null) {
      final subTask = todo.subTasks.firstWhere((st) => st.id == subTaskId);
      subTask.task = newTask;
      await todo.save();
      notifyListeners();
    }
  }
}
