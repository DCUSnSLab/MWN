import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/market.dart';
import '../../providers/market_provider.dart';

class MarketSearchScreen extends StatefulWidget {
  const MarketSearchScreen({super.key});

  @override
  State<MarketSearchScreen> createState() => _MarketSearchScreenState();
}

class _MarketSearchScreenState extends State<MarketSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    if (query.trim().isEmpty) {
      if (mounted) {
        context.read<MarketProvider>().clearSearchResults();
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isSearching = true;
      });
    }

    if (mounted) {
      await context.read<MarketProvider>().searchMarkets(query);
    }

    if (mounted) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  void _addToWatchlist(Market market) async {
    final marketProvider = context.read<MarketProvider>();
    final success = await marketProvider.addToWatchlist(market);
    
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${market.name}이(가) 관심 시장에 추가되었습니다.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(marketProvider.error ?? '관심 시장 추가에 실패했습니다.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('시장 검색'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 검색 입력 필드
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '시장 이름을 입력하세요',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          context.read<MarketProvider>().clearSearchResults();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _performSearch,
              textInputAction: TextInputAction.done,
            ),
          ),
          
          // 검색 결과
          Expanded(
            child: Consumer<MarketProvider>(
              builder: (context, marketProvider, child) {
                if (_isSearching) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (marketProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '오류가 발생했습니다',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          marketProvider.error!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            marketProvider.clearError();
                            if (_searchController.text.isNotEmpty) {
                              _performSearch(_searchController.text);
                            }
                          },
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  );
                }

                if (marketProvider.searchResults.isEmpty) {
                  if (_searchController.text.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '시장 이름을 검색하세요',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '검색 결과가 없습니다',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                }

                return ListView.builder(
                  itemCount: marketProvider.searchResults.length,
                  itemBuilder: (context, index) {
                    final market = marketProvider.searchResults[index];
                    final isInWatchlist = marketProvider.isInWatchlist(market.id);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ListTile(
                        title: Text(
                          market.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(market.location),
                            if (market.category != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                market.category!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: isInWatchlist
                            ? const Icon(
                                Icons.favorite,
                                color: Colors.red,
                              )
                            : IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () => _addToWatchlist(market),
                              ),
                        onTap: isInWatchlist
                            ? null
                            : () => _addToWatchlist(market),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}