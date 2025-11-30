import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  // For Android Emulator, use 10.0.2.2. For Web/iOS/Desktop, use localhost.
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    } else {
      return 'http://localhost:8000';
    }
  }

  Future<String> sendMessage(String message, List<Map<String, String>> history, {String? topicId}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': 'user_1',
          'message': message,
          'topic_id': topicId,
          'history': history,
        }),
      );

      print('Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else {
        throw Exception('Failed to load response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  Future<String> reviewCode(String code, String taskId, String? topicId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/review'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'task_id': taskId,
          'topic_id': topicId ?? "default",
        }),
      );

      print('Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'];
      } else {
        throw Exception('Failed to load response: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error reviewing code: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTopics() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/topics'));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load topics');
      }
    } catch (e) {
      print('Error fetching topics: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> createTopic(String title) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/topics?title=$title'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create topic');
      }
    } catch (e) {
      print('Error creating topic: $e');
      return null;
    }
  }

  Future<bool> deleteTopic(String topicId) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/topics/$topicId'));
      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to delete topic');
      }
    } catch (e) {
      print('Error deleting topic: $e');
      return false;
    }
  }

  Future<List<Map<String, String>>> getHistory(String topicId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/history/$topicId'));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => {
          'role': e['role'].toString(),
          'content': e['content'].toString()
        }).toList();
      } else {
        throw Exception('Failed to load history');
      }
    } catch (e) {
      print('Error fetching history: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> generateTask(String topicId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/tasks/generate?topic_id=$topicId'),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to generate task');
      }
    } catch (e) {
      print('Error generating task: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getTasks(String? topicId) async {
    try {
      String url = '$baseUrl/tasks';
      if (topicId != null) {
        url += '?topic_id=$topicId';
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((e) => e as Map<String, dynamic>).toList();
      } else {
        throw Exception('Failed to load tasks');
      }
    } catch (e) {
      print('Error fetching tasks: $e');
      return [];
    }
  }

  Future<bool> updateTask(String taskId, Map<String, dynamic> taskData) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/tasks/$taskId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(taskData),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to update task');
      }
    } catch (e) {
      print('Error updating task: $e');
      return false;
    }
  }
  Future<Map<String, String>> executeCode(String code, String language) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/execute'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'code': code,
          'language': language,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'output': data['output'] ?? '',
          'error': data['error'] ?? '',
        };
      } else {
        throw Exception('Failed to execute code');
      }
    } catch (e) {
      print('Error executing code: $e');
      return {'output': '', 'error': 'Error: $e'};
    }
  }
}
