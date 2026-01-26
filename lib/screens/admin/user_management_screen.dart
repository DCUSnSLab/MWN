import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final ApiService _apiService = ApiService();
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final users = await _apiService.getAllUsers();
      setState(() {
        _users = users;
        _filteredUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          return user.name.toLowerCase().contains(query.toLowerCase()) ||
                 user.email.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _showCreateUserDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateUserDialog(
        onUserCreated: () {
          _loadUsers();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 관리'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateUserDialog,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
      body: Column(
        children: [
          // 검색 바
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: '이름 또는 이메일로 검색...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              textInputAction: TextInputAction.done,
            ),
          ),

          // 사용자 목록
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorWidget()
                    : _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('사용자 목록 로드 실패', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_error!),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadUsers,
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (_filteredUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('사용자가 없습니다'),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredUsers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: user.role == 'admin' ? Colors.purple : Colors.blue,
          child: Text(
            user.name.substring(0, 1).toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.email),
            const SizedBox(height: 4),
            if (user.phone != null)
              Text('📞 ${user.phone}'),
            if (user.location != null)
              Text('📍 ${user.location}'),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildRoleBadge(user.role),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (user.fcmToken != null)
                  const Icon(Icons.notifications_active, size: 16, color: Colors.green)
                else
                  const Icon(Icons.notifications_off, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Icon(
                  user.isActive ? Icons.check_circle : Icons.cancel,
                  size: 16,
                  color: user.isActive ? Colors.green : Colors.red,
                ),
              ],
            ),
          ],
        ),
        onTap: () {
          _showUserDetailsDialog(user);
        },
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final isAdmin = role == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin ? Colors.purple : Colors.blue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        isAdmin ? '관리자' : '일반',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showUserDetailsDialog(User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${user.name} 정보'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('이메일', user.email),
            if (user.phone != null) _buildDetailRow('전화번호', user.phone!),
            if (user.location != null) _buildDetailRow('위치', user.location!),
            _buildDetailRow('권한', user.role == 'admin' ? '관리자' : '일반 사용자'),
            _buildDetailRow('상태', user.isActive ? '활성' : '비활성'),
            _buildDetailRow('FCM', user.fcmToken != null ? '등록됨' : '미등록'),
            if (user.createdAt != null)
              _buildDetailRow('가입일', user.createdAt!.toString().split(' ')[0]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _CreateUserDialog extends StatefulWidget {
  final VoidCallback onUserCreated;

  const _CreateUserDialog({required this.onUserCreated});

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  final ApiService _apiService = ApiService();
  
  String _selectedRole = 'user';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.createUser(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        role: _selectedRole,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사용자가 생성되었습니다')),
        );
        widget.onUserCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사용자 생성 실패: $e')),
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
    return AlertDialog(
      title: const Text('새 사용자 생성'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '이름',
                  border: OutlineInputBorder(),
                  helperText: '최소 8자, 대문자/소문자/숫자 포함',
                ),
                textInputAction: TextInputAction.done,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이름을 입력하세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이메일을 입력하세요';
                  }
                  if (!value.contains('@')) {
                    return '올바른 이메일 형식이 아닙니다';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '비밀번호를 입력하세요';
                  }
                  if (value.length < 6) {
                    return '비밀번호는 최소 6자 이상이어야 합니다';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '전화번호 (선택사항)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: '위치 (선택사항)',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: '권한',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'user', child: Text('일반 사용자')),
                  DropdownMenuItem(value: 'admin', child: Text('관리자')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createUser,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('생성'),
        ),
      ],
    );
  }
}