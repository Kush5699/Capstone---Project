// lib/screens/workstation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/monokai-sublime.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/dart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class WorkstationScreen extends StatefulWidget {
  @override
  _WorkstationScreenState createState() => _WorkstationScreenState();
}

class _WorkstationScreenState extends State<WorkstationScreen> {
  final ApiService _apiService = ApiService();

  // Editor State
  List<Map<String, dynamic>> _openFiles = [
    {'name': 'main.py', 'content': 'print("Hello World")', 'language': python}
  ];
  int _activeFileIndex = 0;

  late CodeController _codeController;

  // Task & Feedback State
  String _taskContent = "Click 'Get New Task' to start your job simulation.";
  String _feedbackContent = "Submit your code to receive feedback.";
  String _consoleOutput = "Console ready...\n";

  bool _isLoading = false;
  bool _isRunning = false;

  List<Map<String, dynamic>> _topics = [];
  String? _selectedTopicId;

  List<Map<String, dynamic>> _tasks = [];
  Map<String, dynamic>? _currentTask;

  // Use Area(size/min/max/flex/data) — matches multi_split_view >= 3.x API.
  // Left area: initial pixel size 300, min 240px, max 420px.
  // Right area: flex fills remaining space and has a min size to avoid collapsing.
  final MultiSplitViewController _horizontalController = MultiSplitViewController(
    areas: [
      Area(size: 300.0, min: 240.0, max: 420.0, data: 'left'),
      Area(flex: 1.0, min: 360.0, data: 'right'),
    ],
  );

  // Vertical split for right side: top (editor) and bottom (terminal)
  final MultiSplitViewController _verticalController = MultiSplitViewController(
    areas: [
      Area(flex: 0.72, min: 200.0, data: 'top'),
      Area(flex: 0.28, min: 120.0, data: 'bottom'),
    ],
  );

  @override
  void initState() {
    super.initState();
    _initializeEditor();
    _fetchTopics();
    _fetchTasks();
  }

  void _initializeEditor() {
    _codeController = CodeController(
      text: _openFiles[_activeFileIndex]['content'],
      language: _openFiles[_activeFileIndex]['language'],
    );
    _codeController.addListener(() {
      _openFiles[_activeFileIndex]['content'] = _codeController.text;
    });
  }

  void _openFile(String name, String content, {mode}) {
    if (mode == null) {
      if (name.endsWith(".py")) mode = python;
      else if (name.endsWith(".js")) mode = javascript;
      else if (name.endsWith(".dart")) mode = dart;
      else mode = python; // Default
    }

    setState(() {
      _openFiles.add({'name': name, 'content': content, 'language': mode});
      _activeFileIndex = _openFiles.length - 1;
      _codeController.text = content;
    });
  }

  void _closeFile(int index) {
    if (_openFiles.length <= 1) return;
    setState(() {
      _openFiles.removeAt(index);
      if (_activeFileIndex >= index) {
        _activeFileIndex = (_activeFileIndex - 1).clamp(0, _openFiles.length - 1);
      }
      _codeController.text = _openFiles[_activeFileIndex]['content'];
    });
  }

  void _switchFile(int index) {
    setState(() {
      _activeFileIndex = index;
      _codeController.text = _openFiles[index]['content'];
    });
  }

  Future<void> _fetchTopics() async {
    final topics = await _apiService.getTopics();
    setState(() {
      _topics = topics;
      if (_topics.isNotEmpty) {
        _selectedTopicId = _topics.first['id'];
      }
    });
  }

  Future<void> _fetchTasks() async {
    // Fetch all tasks for the drawer
    final tasks = await _apiService.getTasks(null);
    setState(() {
      _tasks = tasks;
    });
  }

  void _selectTask(Map<String, dynamic> task) {
    // Save current task state if exists
    if (_currentTask != null) {
      _saveTaskState();
    }

    setState(() {
      _currentTask = task;
      // Use explicit \n escapes rather than raw multiline to avoid accidental newline tokens.
      _taskContent = "## ${task['title']}\n\n${task['description']}";
      _codeController.text = task['code'] ?? "";
      _feedbackContent = task['feedback'] ?? "Submit your code to receive feedback.";
      if (_codeController.text.isEmpty) {
        // Use triple quotes for the initial code snippet so we keep the newlines.
        _codeController.text = '''
import main

def solution():
    print("Hello World")
''';
      }
    });
  }

  void _saveTaskState() async {
    if (_currentTask == null) return;

    final updatedTask = {
      ..._currentTask!,
      'code': _codeController.text,
      'feedback': _feedbackContent,
      'status': _currentTask!['status'] // Preserve status
    };

    await _apiService.updateTask(_currentTask!['id'], updatedTask);
    _fetchTasks(); // Refresh list to show updates
  }

  void _getTask() async {
    if (_selectedTopicId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please select a topic first.")));
      return;
    }

    setState(() => _isLoading = true);

    final newTask = await _apiService.generateTask(_selectedTopicId!);

    setState(() {
      _isLoading = false;
      if (newTask != null) {
        _tasks.add(newTask);
        _selectTask(newTask);
      }
    });
  }

  void _runCode() async {
    setState(() {
      _isRunning = true;
      _consoleOutput += "\n> Running ${_openFiles[_activeFileIndex]['name']}...\n";
    });

    final result = await _apiService.executeCode(_codeController.text, "python");

    setState(() {
      _isRunning = false;
      final out = result['output'];
      final err = result['error'];
      if (out != null && (out as String).isNotEmpty) {
        _consoleOutput += out as String;
      }
      if (err != null && (err as String).isNotEmpty) {
        _consoleOutput += "\nError:\n${err}";
      }
      _consoleOutput += "\n";
    });
  }

  void _clearConsole() {
    setState(() {
      _consoleOutput = "Console ready...\n";
    });
  }

  void _submitCode() async {
    if (_codeController.text.isEmpty) return;
    setState(() => _isLoading = true);

    final message =
        "Review the following Python code submission. Provide feedback on correctness, style, and efficiency. If the code is correct and solves the task, explicitly state 'APPROVED' in the first line. Code:\n${_codeController.text}";
    final response = await _apiService.sendMessage(message, []);

    bool isApproved = response.contains("APPROVED");

    setState(() {
      _feedbackContent = response;
      _isLoading = false;

      if (isApproved && _currentTask != null) {
        _currentTask!['status'] = "Completed";
        _saveTaskState();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Task Completed! Great job!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Code Submitted. Check Feedback.")),
        );
      }
    });
  }

  void _getSuggestions() async {
    if (_codeController.text.isEmpty) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );

    final message = "I am writing this code. Please provide suggestions, completions, or improvements. Code:\n${_codeController.text}";
    final response = await _apiService.sendMessage(message, []);

    // Close loading dialog
    Navigator.pop(context);

    // Show suggestions dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Code Suggestions"),
        content: SingleChildScrollView(
          child: MarkdownBody(data: response),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Left Panel: Tabs for Task and Feedback
    Widget leftPanel = DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: "Task"),
              Tab(text: "Feedback"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Task Tab
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton.icon(
                        onPressed: _getTask,
                        icon: Icon(Icons.assignment_add, size: 16),
                        label: Text("Get New Task"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFA709A),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (_topics.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _selectedTopicId,
                          hint: Text("Select Topic Context"),
                          items: _topics.map((topic) {
                            return DropdownMenuItem<String>(
                              value: topic['id'],
                              child: Text(topic['title']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTopicId = value;
                            });
                          },
                        ),
                      ),
                    Expanded(
                      child: _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                        padding: EdgeInsets.all(16),
                        child: MarkdownBody(data: _taskContent),
                      ),
                    ),
                  ],
                ),
                // Feedback Tab
                SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: MarkdownBody(data: _feedbackContent),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Right Panel: Editor (Top) and Console (Bottom)
    Widget editorPanel = Column(
      children: [
        // Editor Tab Bar
        Container(
          color: Color(0xFF1E1E1E),
          height: 35,
          child: Row(
            children: [
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _openFiles.length,
                  itemBuilder: (context, index) {
                    final file = _openFiles[index];
                    final isActive = index == _activeFileIndex;
                    return GestureDetector(
                      onTap: () => _switchFile(index),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive ? Color(0xFF2D2D2D) : Color(0xFF1E1E1E),
                          border: Border(
                            top: BorderSide(color: isActive ? Colors.blue : Colors.transparent, width: 2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              file['name'],
                              style: GoogleFonts.firaCode(
                                color: isActive ? Colors.white : Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            if (_openFiles.length > 1)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: InkWell(
                                  onTap: () => _closeFile(index),
                                  child: Icon(Icons.close, size: 14, color: Colors.grey),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.add, color: Colors.grey, size: 18),
                onPressed: () => _openFile("new_file.py", ""),
                tooltip: "New File",
              ),
            ],
          ),
        ),
        // Editor Action Bar
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Color(0xFF2D2D2D),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isRunning)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                ),
              OutlinedButton.icon(
                onPressed: _getSuggestions,
                icon: Icon(Icons.lightbulb_outline, size: 16),
                label: Text("Suggest"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.yellowAccent,
                  side: BorderSide(color: Colors.yellowAccent.withOpacity(0.5)),
                ),
              ),
              SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _runCode,
                icon: Icon(Icons.play_arrow, size: 16),
                label: Text("Run Code"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.greenAccent,
                  side: BorderSide(color: Colors.greenAccent.withOpacity(0.5)),
                ),
              ),
              SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _submitCode,
                icon: Icon(Icons.check, size: 16),
                label: Text("Submit"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Code Editor
        Expanded(
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.enter, control: true): () => _runCode(),
              const SingleActivator(LogicalKeyboardKey.space, control: true): () => _getSuggestions(),
            },
            child: Focus(
              autofocus: true,
              child: CodeTheme(
                data: CodeThemeData(styles: monokaiSublimeTheme),
                child: Container(
                  color: Color(0xFF1E1E1E),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        height: constraints.maxHeight,
                        width: double.infinity,
                        child: CodeField(
                            controller: _codeController,
                            textStyle: GoogleFonts.firaCode(
                              fontSize: 14,
                              color: Colors.white,
                            ),

                            // These two flags prevent overflow
                            expands: true,
                            minLines: null,
                            maxLines: null,
                          ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    Widget consolePanel = Container(
      color: Colors.black,
      width: double.infinity,
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Terminal", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.grey, size: 16),
                onPressed: _clearConsole,
                tooltip: "Clear Console",
              ),
            ],
          ),
          Divider(color: Colors.grey[800], height: 1),
          Expanded(
            child: SingleChildScrollView(
              reverse: true, // Auto-scroll to bottom
              child: Text(
                _consoleOutput,
                style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );

    Widget rightPanel = MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 10,
        dividerPainter: DividerPainters.grooved1(color: Colors.grey[300]!, highlightedColor: Colors.blue),
      ),
      child: MultiSplitView(
        axis: Axis.vertical,
        controller: _verticalController,
        resizable: true,
        builder: (context, area) {
          if (area.data == 'top') return editorPanel;
          if (area.data == 'bottom') return consolePanel;
          return Container();
        },
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Workstation', style: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      endDrawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text("My Tasks"),
              accountEmail: Text("Select a task to resume"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.assignment, color: Color(0xFFFA709A)),
              ),
              decoration: BoxDecoration(color: Color(0xFFFA709A)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _topics.length,
                itemBuilder: (context, index) {
                  final topic = _topics[index];
                  final topicTasks = _tasks.where((t) => t['topic_id'] == topic['id']).toList();

                  if (topicTasks.isEmpty) return SizedBox.shrink();

                  return ExpansionTile(
                    title: Text(topic['title'], style: TextStyle(fontWeight: FontWeight.bold)),
                    initiallyExpanded: true,
                    children: topicTasks.map((task) {
                      final isCompleted = task['status'] == 'Completed';
                      final isSelected = _currentTask != null && _currentTask!['id'] == task['id'];

                      return ListTile(
                        leading: Icon(
                          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: isCompleted ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        title: Text(
                          task['title'],
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(task['status'], style: TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onTap: () {
                          Navigator.pop(context);
                          _selectTask(task);
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: MultiSplitViewTheme(
        data: MultiSplitViewThemeData(
          dividerThickness: 10,
          dividerPainter: DividerPainters.grooved1(color: Colors.grey[300]!, highlightedColor: Colors.blue),
        ),
        child: MultiSplitView(
          axis: Axis.horizontal,
          controller: _horizontalController,
          resizable: true,
          builder: (context, area) {
            if (area.data == 'left') return leftPanel;
            if (area.data == 'right') return rightPanel;
            return Container();
          },
        ),
      ),
    );
  }
}
