import 'package:flutter/material.dart';
import 'classroom_screen.dart';
import 'workstation_screen.dart';

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('CareerForge AI', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Choose Your Path",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
              ),
              SizedBox(height: 40),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: [
                  _buildCard(
                    context,
                    'Classroom',
                    'Learn new concepts with your AI Mentor.',
                    Icons.school_rounded,
                    [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ClassroomScreen()),
                    ),
                  ),
                  _buildCard(
                    context,
                    'Workstation',
                    'Apply your skills in a simulated job.',
                    Icons.work_rounded,
                    [Color(0xFFFA709A), Color(0xFFFEE140)],
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WorkstationScreen()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, String subtitle, IconData icon, List<Color> gradientColors, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 300,
        height: 220,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.3),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.9)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
