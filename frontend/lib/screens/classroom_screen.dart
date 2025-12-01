import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ClassroomScreen extends StatefulWidget {
  @override
  _ClassroomScreenState createState() => _ClassroomScreenState();
}

class _ClassroomScreenState extends State<ClassroomScreen> {
  final TextEditingController _controller = TextEditingController();
  final ApiService _apiService = ApiService();
  List<Map<String, String>> _messages = [
    {'role': 'agent', 'content': 'Hello! I am your AI Mentor. Select a topic or start a new one!'}
  ];
  List<Map<String, dynamic>> _topics = [];
  String? _currentTopicId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTopics();
  }

  void _fetchTopics() async {
    final topics = await _apiService.getTopics();
    setState(() {
      _topics = topics;
      if (_topics.isNotEmpty && _currentTopicId == null) {
        _selectTopic(_topics.first['id']);
      }
    });
  }

  void _selectTopic(String topicId) async {
    setState(() {
      _currentTopicId = topicId;
      _isLoading = true;
    });
    
    final history = await _apiService.getHistory(topicId);
    setState(() {
      _messages = history.map((e) => {'role': e['role']!, 'content': e['content']!}).toList();
      if (_messages.isEmpty) {
         _messages = [{'role': 'agent', 'content': 'Hello! I am your AI Mentor. Ask me anything about this topic.'}];
      }
      _isLoading = false;
    });
  }

  void _createNewTopic() {
    showDialog(
      context: context,
      builder: (context) {
        String newTopicTitle = "";
        return AlertDialog(
          title: Text("New Topic"),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(hintText: "Enter topic name (e.g., Python Basics)"),
            onChanged: (value) => newTopicTitle = value,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
            TextButton(
              onPressed: () async {
                if (newTopicTitle.isNotEmpty) {
                  Navigator.pop(context);
                  final newTopic = await _apiService.createTopic(newTopicTitle);
                  if (newTopic != null) {
                    _fetchTopics(); // Refresh list
                    _selectTopic(newTopic['id']); // Switch to new topic
                  }
                }
              },
              child: Text("Create"),
            ),
          ],
        );
      },
    );
  }

  void _deleteTopic(String topicId) async {
    final success = await _apiService.deleteTopic(topicId);
    if (success) {
      setState(() {
        _topics.removeWhere((t) => t['id'] == topicId);
        if (_currentTopicId == topicId) {
          _currentTopicId = null;
          _messages = [{'role': 'agent', 'content': 'Topic deleted. Select another topic or create a new one.'}];
          if (_topics.isNotEmpty) {
             _selectTopic(_topics.first['id']);
          }
        }
      });
    }
  }

  void _sendMessage() async {
    if (_controller.text.isEmpty) return;

    final userMessage = _controller.text;
    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
      _isLoading = true;
    });
    _controller.clear();

    final response = await _apiService.sendMessage(userMessage, [], topicId: _currentTopicId);

    setState(() {
      _messages.add({'role': 'agent', 'content': response});
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Classroom', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text("My Learning"),
              accountEmail: Text("Select a topic to continue"),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.school, color: Colors.blue),
              ),
              decoration: BoxDecoration(color: Color(0xFF4FACFE)),
            ),
            ListTile(
              leading: Icon(Icons.add),
              title: Text("New Topic"),
              onTap: _createNewTopic,
            ),
            Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _topics.length,
                itemBuilder: (context, index) {
                  final topic = _topics[index];
                  final isSelected = topic['id'] == _currentTopicId;
                  return ListTile(
                    leading: Icon(Icons.chat_bubble_outline, color: isSelected ? Colors.blue : Colors.grey),
                    title: Text(
                      topic['title'],
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.blue : Colors.black87,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                      onPressed: () {
                         showDialog(
                           context: context,
                           builder: (context) => AlertDialog(
                             title: Text("Delete Topic?"),
                             content: Text("Are you sure you want to delete '${topic['title']}'? This cannot be undone."),
                             actions: [
                               TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancel")),
                               TextButton(
                                 onPressed: () {
                                   Navigator.pop(context);
                                   _deleteTopic(topic['id']);
                                 },
                                 child: Text("Delete", style: TextStyle(color: Colors.red)),
                               ),
                             ],
                           ),
                         );
                      },
                    ),
                    selected: isSelected,
                    onTap: () {
                      Navigator.pop(context); // Close drawer
                      _selectTopic(topic['id']);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: EdgeInsets.only(bottom: 16),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isUser ? Color(0xFF4FACFE) : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: isUser ? Radius.circular(20) : Radius.circular(0),
                        bottomRight: isUser ? Radius.circular(0) : Radius.circular(20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: MarkdownBody(
                      data: msg['content']!,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          color: isUser ? Colors.white : Color(0xFF333333),
                          fontSize: 16,
                          height: 1.4,
                        ),
                        strong: TextStyle(
                          color: isUser ? Colors.white : Color(0xFF333333),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask your mentor...',
                      filled: true,
                      fillColor: Color(0xFFF5F7FA),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 12),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  backgroundColor: Color(0xFF4FACFE),
                  child: Icon(Icons.send, color: Colors.white),
                  elevation: 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
