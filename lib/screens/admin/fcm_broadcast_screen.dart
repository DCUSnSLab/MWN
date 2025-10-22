import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';

class FCMBroadcastScreen extends StatefulWidget {
  const FCMBroadcastScreen({super.key});

  @override
  State<FCMBroadcastScreen> createState() => _FCMBroadcastScreenState();
}

class _FCMBroadcastScreenState extends State<FCMBroadcastScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM 브로드캐스트'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '전체 전송', icon: Icon(Icons.all_inclusive)),
            Tab(text: '주제 전송', icon: Icon(Icons.topic)),
            Tab(text: '선택 전송', icon: Icon(Icons.people)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BroadcastToAllTab(apiService: _apiService),
          _BroadcastToTopicTab(apiService: _apiService),
          _BroadcastToUsersTab(apiService: _apiService),
        ],
      ),
    );
  }
}

class _BroadcastToAllTab extends StatefulWidget {
  final ApiService apiService;

  const _BroadcastToAllTab({required this.apiService});

  @override
  State<_BroadcastToAllTab> createState() => _BroadcastToAllTabState();
}

class _BroadcastToAllTabState extends State<_BroadcastToAllTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.apiService.sendAdminFCMBroadcast(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전체 사용자에게 알림이 전송되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        _titleController.clear();
        _bodyController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('알림 전송 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          '전체 사용자 브로드캐스트',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'FCM이 활성화된 모든 사용자에게 알림이 전송됩니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '알림 제목',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '제목을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: '알림 내용',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '내용을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendBroadcast,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_isLoading ? '전송 중...' : '전체 전송'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BroadcastToTopicTab extends StatefulWidget {
  final ApiService apiService;

  const _BroadcastToTopicTab({required this.apiService});

  @override
  State<_BroadcastToTopicTab> createState() => _BroadcastToTopicTabState();
}

class _BroadcastToTopicTabState extends State<_BroadcastToTopicTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _topicController = TextEditingController();
  bool _isLoading = false;

  final List<String> _predefinedTopics = [
    'weather_alerts',
    'emergency_alerts',
    'system_notices',
    'promotions',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _sendTopicBroadcast() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.apiService.sendAdminFCMBroadcast(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        topic: _topicController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('주제 "${_topicController.text.trim()}"로 알림이 전송되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        _titleController.clear();
        _bodyController.clear();
        _topicController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('알림 전송 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.topic, color: Colors.orange[700]),
                        const SizedBox(width: 8),
                        Text(
                          '주제별 브로드캐스트',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '특정 주제를 구독한 사용자들에게만 알림이 전송됩니다.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _topicController,
              decoration: const InputDecoration(
                labelText: '주제명',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.topic),
                hintText: 'weather_alerts',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '주제명을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _predefinedTopics.map((topic) {
                return ActionChip(
                  label: Text(topic),
                  onPressed: () {
                    _topicController.text = topic;
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '알림 제목',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '제목을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: '알림 내용',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '내용을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _sendTopicBroadcast,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_isLoading ? '전송 중...' : '주제 전송'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BroadcastToUsersTab extends StatefulWidget {
  final ApiService apiService;

  const _BroadcastToUsersTab({required this.apiService});

  @override
  State<_BroadcastToUsersTab> createState() => _BroadcastToUsersTabState();
}

class _BroadcastToUsersTabState extends State<_BroadcastToUsersTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  
  List<User> _users = [];
  List<User> _selectedUsers = [];
  bool _isLoadingUsers = false;
  bool _isSending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _error = null;
    });

    try {
      final users = await widget.apiService.getAllUsers();
      setState(() {
        _users = users.where((user) => user.fcmToken != null).toList();
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _sendToSelectedUsers() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전송할 사용자를 선택하세요')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final userIds = _selectedUsers.map((user) => user.id).toList();
      await widget.apiService.sendAdminFCMBroadcast(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        userIds: userIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('선택된 ${_selectedUsers.length}명에게 알림이 전송되었습니다'),
            backgroundColor: Colors.green,
          ),
        );
        _titleController.clear();
        _bodyController.clear();
        setState(() {
          _selectedUsers.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('알림 전송 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.people, color: Colors.purple[700]),
                        const SizedBox(width: 8),
                        Text(
                          '선택 사용자 브로드캐스트',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.purple[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '선택된 사용자들에게만 알림이 전송됩니다. (${_selectedUsers.length}명 선택됨)',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '알림 제목',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '제목을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: '알림 내용',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.message),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '내용을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('사용자 선택:', style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_selectedUsers.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedUsers.clear();
                      });
                    },
                    child: const Text('전체 해제'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoadingUsers
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text('사용자 로드 실패: $_error'))
                      : _buildUserList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSending ? null : _sendToSelectedUsers,
              icon: _isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_isSending ? '전송 중...' : '선택 전송'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList() {
    if (_users.isEmpty) {
      return const Center(
        child: Text('FCM이 활성화된 사용자가 없습니다'),
      );
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        final isSelected = _selectedUsers.contains(user);

        return CheckboxListTile(
          title: Text(user.name),
          subtitle: Text(user.email),
          value: isSelected,
          onChanged: (selected) {
            setState(() {
              if (selected == true) {
                _selectedUsers.add(user);
              } else {
                _selectedUsers.remove(user);
              }
            });
          },
          secondary: CircleAvatar(
            backgroundColor: user.role == 'admin' ? Colors.purple : Colors.blue,
            child: Text(
              user.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}