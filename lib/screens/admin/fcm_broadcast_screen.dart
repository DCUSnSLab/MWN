import 'package:flutter/material.dart';
import '../../repositories/admin_repository.dart';
import '../../models/user.dart';
import 'alert_history_screen.dart';
import '../../utils/logger.dart';

class FCMBroadcastScreen extends StatefulWidget {
  const FCMBroadcastScreen({super.key});

  @override
  State<FCMBroadcastScreen> createState() => _FCMBroadcastScreenState();
}

class _FCMBroadcastScreenState extends State<FCMBroadcastScreen> {
  final AdminRepository _adminRepository = AdminRepository();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM 브로드캐스트'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '발송 이력',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AlertHistoryScreen()),
              );
            },
          ),
        ],
      ),
      // 전체 전송 / 주제 전송 탭은 실수 발송 위험 vs 운영 가치 낮음으로 제거.
      // 선택 전송만 유지.
      body: _BroadcastToUsersTab(adminRepository: _adminRepository),
    );
  }
}

class _BroadcastToUsersTab extends StatefulWidget {
  final AdminRepository adminRepository;

  const _BroadcastToUsersTab({required this.adminRepository});

  @override
  State<_BroadcastToUsersTab> createState() => _BroadcastToUsersTabState();
}

class _BroadcastToUsersTabState extends State<_BroadcastToUsersTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  
  List<User> _users = [];
  final List<User> _selectedUsers = [];
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
      final users = await widget.adminRepository.getAllUsers();
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
      log('선택 사용자 FCM 브로드캐스트 시작 - 사용자 ${userIds.length}명: $userIds');
      await widget.adminRepository.sendAdminFCMBroadcast(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        userIds: userIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('선택된 ${_selectedUsers.length}명에게 알림이 전송되었습니다'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _titleController.clear();
        _bodyController.clear();
        setState(() {
          _selectedUsers.clear();
        });
      }
      log('선택 사용자 FCM 브로드캐스트 완료');
    } catch (e) {
      log('선택 사용자 FCM 브로드캐스트 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('알림 전송 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
              textInputAction: TextInputAction.done,
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
              textInputAction: TextInputAction.done,
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