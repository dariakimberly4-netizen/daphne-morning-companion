import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

void main() => runApp(const DaphneApp());

class DaphneApp extends StatelessWidget {
  const DaphneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Daphne Morning Companion',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF674188)),
        scaffoldBackgroundColor: const Color(0xFFFFFBF4),
        useMaterial3: true,
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          titleLarge: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontSize: 21, height: 1.35),
        ),
      ),
      home: const MorningScreen(),
    );
  }
}

class MorningTask {
  MorningTask({required this.id, required this.title, this.done = false});
  final String id;
  String title;
  bool done;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'done': done};
  factory MorningTask.fromJson(Map<String, dynamic> json) => MorningTask(
        id: json['id'] as String,
        title: json['title'] as String,
        done: json['done'] as bool? ?? false,
      );
}

class MorningScreen extends StatefulWidget {
  const MorningScreen({super.key});
  @override
  State<MorningScreen> createState() => _MorningScreenState();
}

class _MorningScreenState extends State<MorningScreen> {
  final FlutterTts _voice = FlutterTts();
  final _uuid = const Uuid();
  List<MorningTask> _tasks = [];
  int _current = 0;
  bool _speaking = false;

  MorningTask? get currentTask {
    final remaining = _tasks.where((task) => !task.done).toList();
    if (remaining.isEmpty) return null;
    if (_current >= remaining.length) _current = 0;
    return remaining[_current];
  }

  @override
  void initState() {
    super.initState();
    _configureVoice();
    _loadTasks();
  }

  Future<void> _configureVoice() async {
    await _voice.setLanguage('en-PH');
    await _voice.setSpeechRate(0.42);
    await _voice.setPitch(1.0);
    _voice.setStartHandler(() => mounted ? setState(() => _speaking = true) : null);
    _voice.setCompletionHandler(() => mounted ? setState(() => _speaking = false) : null);
    _voice.setCancelHandler(() => mounted ? setState(() => _speaking = false) : null);
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('morning_tasks');
    if (stored == null) {
      _tasks = [
        MorningTask(id: _uuid.v4(), title: 'Prepare breakfast'),
        MorningTask(id: _uuid.v4(), title: 'Check today’s appointments'),
        MorningTask(id: _uuid.v4(), title: 'Bring your phone, keys, wallet, and ID'),
      ];
      await _saveTasks();
    } else {
      _tasks = (jsonDecode(stored) as List)
          .map((item) => MorningTask.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('morning_tasks', jsonEncode(_tasks.map((e) => e.toJson()).toList()));
  }

  Future<void> _speakCurrent() async {
    final task = currentTask;
    if (_speaking) {
      await _voice.stop();
      return;
    }
    if (task == null) {
      await _voice.speak('Wonderful, Jasmin. You finished all your morning tasks.');
    } else {
      await _voice.speak('Jasmin, your current task is: ${task.title}. Tap me again when you finish.');
    }
  }

  Future<void> _askToFinish() async {
    final task = currentTask;
    if (task == null) return _speakCurrent();
    await _voice.speak('Have you finished ${task.title}?');
    if (!mounted) return;
    final finished = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task finished?', style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold)),
        content: Text(task.title, style: const TextStyle(fontSize: 22)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, false),
            child: const Padding(padding: EdgeInsets.all(14), child: Text('NOT YET', style: TextStyle(fontSize: 20))),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Padding(padding: EdgeInsets.all(14), child: Text('YES, DONE', style: TextStyle(fontSize: 20))),
          ),
        ],
      ),
    );
    if (finished == true) {
      task.done = true;
      await _saveTasks();
      setState(() {});
      await _voice.speak(currentTask == null
          ? 'Well done, Jasmin. You finished all your morning tasks.'
          : 'Done. Great job, Jasmin. Let us go to your next task.');
    }
  }

  Future<void> _addTask() async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a morning task'),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(fontSize: 21),
          decoration: const InputDecoration(hintText: 'What should Jasmin remember?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('ADD TASK')),
        ],
      ),
    );
    if (title != null && title.isNotEmpty) {
      _tasks.add(MorningTask(id: _uuid.v4(), title: title));
      await _saveTasks();
      setState(() {});
    }
  }

  Future<void> _resetMorning() async {
    for (final task in _tasks) task.done = false;
    _current = 0;
    await _saveTasks();
    setState(() {});
    await _voice.speak('Your morning checklist is ready, Jasmin.');
  }

  @override
  void dispose() {
    _voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = currentTask;
    final completed = _tasks.where((task) => task.done).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daphne'),
        centerTitle: true,
        actions: [IconButton(onPressed: _resetMorning, tooltip: 'Start a new morning', icon: const Icon(Icons.refresh, size: 30))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        icon: const Icon(Icons.add, size: 30),
        label: const Text('ADD TASK', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 110),
          children: [
            const Text('Good morning, Jasmin', textAlign: TextAlign.center, style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('$completed of ${_tasks.length} tasks finished', textAlign: TextAlign.center, style: const TextStyle(fontSize: 19)),
            const SizedBox(height: 10),
            Semantics(
              button: true,
              label: _speaking ? 'Tap Daphne to stop speaking' : 'Tap Daphne to hear the task',
              child: GestureDetector(
                onTap: _speakCurrent,
                onDoubleTap: _askToFinish,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 180),
                  scale: _speaking ? 1.025 : 1,
                  child: Container(
                    height: 315,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFE8D5F5), Color(0xFF8B5BA7)],
                      ),
                    ),
                    child: const Icon(Icons.face_3_rounded, size: 210, color: Color(0xFFFFF8ED)),
                  ),
                ),
              ),
            ),
            Text(_speaking ? 'Daphne is speaking… Tap her to stop.' : 'Tap Daphne to hear the task. Double-tap her when finished.',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF674188))),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              color: const Color(0xFFF0E5F8),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(children: [
                  Text(task == null ? 'All tasks are finished!' : task.title,
                      textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  if (task != null)
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: FilledButton.icon(
                        onPressed: _askToFinish,
                        icon: const Icon(Icons.check_circle_outline, size: 31),
                        label: const Text('I FINISHED THIS', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: OutlinedButton.icon(
                      onPressed: _speakCurrent,
                      icon: Icon(_speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined, size: 29),
                      label: Text(_speaking ? 'STOP SPEAKING' : 'REPEAT TASK', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
