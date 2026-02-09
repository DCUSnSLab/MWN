import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../services/api_service.dart';
import '../../models/market.dart';

class ReportScreen extends StatefulWidget {
  final int? preSelectedMarketId;
  final String? preSelectedMarketName;

  const ReportScreen({
    Key? key, 
    this.preSelectedMarketId, 
    this.preSelectedMarketName
  }) : super(key: key);

  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  
  bool _isLoading = false;
  List<Market> _markets = [];
  Market? _selectedMarket;
  
  // 신고 유형: drainage, fire, odor, other
  final List<Map<String, String>> _reportTypes = [
    {'value': 'drainage', 'label': '배수구 막힘'},
    {'value': 'fire', 'label': '화재 위험'},
    {'value': 'odor', 'label': '악취 발생'},
    {'value': 'other', 'label': '기타'},
  ];
  String? _selectedReportType;
  
  final TextEditingController _descriptionController = TextEditingController();
  
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadMarkets();
  }

  Future<void> _loadMarkets() async {
    try {
      final markets = await _apiService.getMarkets(isActive: true);
      setState(() {
        _markets = markets;
        
        // If a market was pre-selected, find and set it
        if (widget.preSelectedMarketId != null) {
          try {
            _selectedMarket = _markets.firstWhere(
              (m) => m.id == widget.preSelectedMarketId
            );
          } catch (_) {
            // Pre-selected market might not be in the list
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('시장 목록을 불러오는데 실패했습니다: $e')),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('이미지를 불러오는데 실패했습니다: $e')),
      );
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Use selected market OR pre-selected market
    final int? marketId = _selectedMarket?.id ?? widget.preSelectedMarketId;
    
    if (marketId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고할 시장을 선택해주세요.')),
      );
      return;
    }
    if (_selectedReportType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고 유형을 선택해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.submitReport(
        marketId: marketId,
        reportType: _selectedReportType!,
        description: _descriptionController.text,
        imagePath: _imageFile != null ? _imageFile!.path : '',
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('신고 접수 완료'),
          content: const Text('성공적으로 신고가 접수되었습니다.\n관리자 확인 후 조치될 예정입니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 닫기
                Navigator.of(context).pop(); // 화면 종료
              },
              child: const Text('확인'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('신고 접수 실패: $e')),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('시장 문제 신고'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. 시장 선택
                    if (widget.preSelectedMarketId != null)
                      Container(
                        padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.store, color: Colors.grey),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                widget.preSelectedMarketName ?? '선택된 시장',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            const Icon(Icons.lock, size: 16, color: Colors.grey),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<Market>(
                        value: _selectedMarket,
                        decoration: const InputDecoration(
                          labelText: '시장 선택',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.store),
                        ),
                        items: _markets.map((market) {
                          return DropdownMenuItem(
                            value: market,
                            child: Text(market.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedMarket = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? '시장을 선택해주세요.' : null,
                      ),
                    SizedBox(height: 16.h),

                    // 2. 신고 유형 선택
                    DropdownButtonFormField<String>(
                      value: _selectedReportType,
                      decoration: const InputDecoration(
                        labelText: '신고 유형',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: _reportTypes.map((type) {
                        return DropdownMenuItem(
                          value: type['value'],
                          child: Text(type['label']!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedReportType = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? '신고 유형을 선택해주세요.' : null,
                    ),
                    SizedBox(height: 16.h),

                    // 3. 사진 첨부
                    Text('현장 사진', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp)),
                    SizedBox(height: 8.h),
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.camera_alt),
                                  title: const Text('카메라로 촬영'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImage(ImageSource.camera);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.photo_library),
                                  title: const Text('앨범에서 선택'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImage(ImageSource.gallery);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        height: 200.h,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: _imageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8.r),
                                child: Image.file(_imageFile!, fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                                  SizedBox(height: 8.h),
                                  const Text('사진을 첨부해주세요 (선택)', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                      ),
                    ),
                    SizedBox(height: 16.h),

                    // 4. 상세 내용
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: '상세 내용',
                        border: OutlineInputBorder(),
                        hintText: '문제 상황을 상세히 설명해주세요.',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 5,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '상세 내용을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 24.h),

                    // 5. 제출 버튼
                    ElevatedButton(
                      onPressed: _submitReport,
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        backgroundColor: Colors.redAccent,
                      ),
                      child: Text(
                        '신고하기',
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
