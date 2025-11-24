import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter + Nginx + FastAPI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Web + Nginx + FastAPI'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<dynamic> _items = [];
  bool _isLoading = false;
  String _statusMessage = '';
  String _healthStatus = '';

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
    });

    try {
      final response = await http.get(Uri.parse('/api/items'));

      if (response.statusCode == 200) {
        setState(() {
          _items = json.decode(response.body);
          _isLoading = false;
          _statusMessage = 'アイテムを${_items.length}件取得しました';
        });
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = 'エラー: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'エラー: $e';
      });
    }
  }

  Future<void> _healthCheck() async {
    try {
      final response = await http.get(Uri.parse('/api/health'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _healthStatus = 'ステータス: ${data['status']}\nサービス: ${data['service']}';
        });
      } else {
        setState(() {
          _healthStatus = 'ヘルスチェック失敗: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _healthStatus = 'ヘルスチェックエラー: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Nginxをリバースプロキシとして使用したアプリケーション',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nginxがフロントエンドの静的ファイルを配信し、\n/api/* へのリクエストをバックエンド（FastAPI）にプロキシします。',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'API動作確認',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _fetchItems,
                            icon: const Icon(Icons.refresh),
                            label: const Text('アイテム一覧を取得'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: _healthCheck,
                            icon: const Icon(Icons.health_and_safety),
                            label: const Text('ヘルスチェック'),
                          ),
                        ],
                      ),
                      if (_statusMessage.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          _statusMessage,
                          style: TextStyle(
                            color: _statusMessage.contains('エラー')
                                ? Colors.red
                                : Colors.green,
                          ),
                        ),
                      ],
                      if (_healthStatus.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _healthStatus,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_items.isNotEmpty) ...[
                const Text(
                  'アイテム一覧',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ..._items.map((item) => Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.deepPurple,
                          child: Text(
                            '${item['id']}',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          item['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(item['description']),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
