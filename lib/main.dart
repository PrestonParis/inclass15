import 'dart:convert';

import 'package:flutter/material.dart';

import 'question.dart';
import 'trivia_service.dart';

void main() {
  runApp(const TriviaShowdownApp());
}

class TriviaShowdownApp extends StatelessWidget {
  const TriviaShowdownApp({super.key, this.service});

  /// Optional so widget tests can pass in a service with a mock client.
  final TriviaService? service;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'API-to-Cloud Trivia Showdown',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: TriviaShowdownScreen(service: service),
    );
  }
}

class TriviaShowdownScreen extends StatefulWidget {
  const TriviaShowdownScreen({super.key, this.service});

  final TriviaService? service;

  @override
  State<TriviaShowdownScreen> createState() => _TriviaShowdownScreenState();
}

class _TriviaShowdownScreenState extends State<TriviaShowdownScreen> {
  static const String _playerName = 'Preston';

  late final TriviaService _service = widget.service ?? TriviaService();

  List<Question> _questions = [];
  bool _isLoading = true;
  String _error = '';
  int _currentIndex = 0;
  int _score = 0;
  bool _answered = false;
  String? _selectedOption;
  bool _isSynced = false;
  bool _isSyncing = false;
  int _roundId = 0;
  Map<String, Object>? _lastPayload;

  @override
  void initState() {
    super.initState();
    _loadTriviaData();
  }

  Future<void> _loadTriviaData() async {
    final roundId = _roundId;
    try {
      final questions = await _service.fetchQuestions();
      if (!mounted || roundId != _roundId) return;
      setState(() {
        _questions = questions;
        _isLoading = false;
      });
    } on TriviaException catch (e) {
      if (!mounted || roundId != _roundId) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    }
  }

  void _answerQuestion(String option) {
    // Only the first answer for a question counts.
    if (_answered) return;
    setState(() {
      _answered = true;
      _selectedOption = option;
      if (option == _questions[_currentIndex].correctAnswer) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      // Moving past the last question shows the results screen.
      _currentIndex++;
      _answered = false;
      _selectedOption = null;
    });
  }

  Map<String, Object> _buildScorePayload() => {
    'player': _playerName,
    'score': _score,
    'total': _questions.length,
    'category': 'General Knowledge',
    'submittedAt': DateTime.now().toUtc().toIso8601String(),
  };

  /// SIMULATION ONLY: waits one second to mimic a network round trip.
  /// No HTTP request is made and nothing is saved on a server.
  Future<void> _syncScoreToCloud() async {
    if (_isSyncing || _isSynced) return;
    final roundId = _roundId;
    final payload = _buildScorePayload();
    setState(() {
      _isSyncing = true;
      _lastPayload = payload;
    });
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted || roundId != _roundId) return;
    setState(() {
      _isSyncing = false;
      _isSynced = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Simulated sync complete; no backend request was sent.'),
      ),
    );
  }

  void _restart() {
    _roundId++;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _isLoading = true;
      _error = '';
      _questions = [];
      _currentIndex = 0;
      _score = 0;
      _answered = false;
      _selectedOption = null;
      _isSynced = false;
      _isSyncing = false;
      _lastPayload = null;
    });
    _loadTriviaData();
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_isLoading) {
      body = _buildLoading();
    } else if (_error.isNotEmpty) {
      body = _buildError();
    } else if (_currentIndex >= _questions.length) {
      body = _buildResults();
    } else {
      body = _buildQuestion();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Trivia Showdown: API Edition'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(20.0), child: body),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.deepOrange),
          SizedBox(height: 16),
          Text('Fetching 5 questions from Open Trivia DB...'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(
            _error,
            key: const Key('errorText'),
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _restart,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Showdown Complete!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Final Score: $_score / ${_questions.length}',
              key: const Key('finalScore'),
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            if (!_isSynced)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                onPressed: _isSyncing ? null : _syncScoreToCloud,
                icon: const Icon(Icons.cloud_upload),
                label: Text(
                  _isSyncing ? 'Simulating sync...' : 'Simulate Score Sync',
                ),
              )
            else
              const Text(
                '✓ Sync Simulation Complete',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Classroom simulation: no backend request is sent.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            if (_lastPayload != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Payload that a real POST would send:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(
                  const JsonEncoder.withIndent('  ').convert(_lastPayload),
                  style: const TextStyle(fontFamily: 'Courier', fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextButton(onPressed: _restart, child: const Text('Play Again')),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion() {
    final question = _questions[_currentIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: Colors.orange.shade100,
          color: Colors.deepOrange,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentIndex + 1} of ${_questions.length}',
              style: const TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Score: $_score',
              key: const Key('liveScore'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              question.questionText,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: ListView(
            children: question.options.map((opt) {
              Color btnColor = Colors.white;
              if (_answered) {
                if (opt == question.correctAnswer) {
                  btnColor = Colors.green.shade200;
                } else if (opt == _selectedOption) {
                  btnColor = Colors.red.shade200;
                }
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: btnColor,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                  ),
                  onPressed: () => _answerQuestion(opt),
                  child: Text(
                    opt,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_answered) ...[
          Text(
            _selectedOption == question.correctAnswer
                ? 'Correct!'
                : 'Incorrect. The answer is ${question.correctAnswer}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _selectedOption == question.correctAnswer
                  ? Colors.green.shade800
                  : Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _nextQuestion,
            child: Text(
              _currentIndex < _questions.length - 1
                  ? 'Next Question →'
                  : 'View Final Score',
            ),
          ),
        ],
      ],
    );
  }
}
