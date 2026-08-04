import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'add_transaction_screen.dart';
import 'charts_screen.dart';
import 'home_screen.dart';
import 'recurring_edit_screen.dart';
import 'recurring_screen.dart';
import 'search_screen.dart';
import 'settings/settings_screen.dart';

/// Uygulamanın kök kabuğu: 4 sekmeli alt navigasyon + açılış başlatması.
class RootScaffold extends ConsumerStatefulWidget {
  const RootScaffold({super.key});

  @override
  ConsumerState<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends ConsumerState<RootScaffold> {
  int _index = 0;

  static const _titles = [
    'Kesem',
    'Grafikler',
    'Tekrarlayanlar',
    'Ayarlar',
  ];

  void _openAdd() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
  }

  void _openAddRecurring() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecurringEditScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final init = ref.watch(appInitProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (_index == 0)
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Ara',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
            ),
        ],
      ),
      body: init.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Başlatma hatası:\n$e', textAlign: TextAlign.center),
          ),
        ),
        data: (_) => IndexedStack(
          index: _index,
          children: const [
            HomeTab(),
            ChartsScreen(),
            RecurringScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      floatingActionButton: switch (_index) {
        0 => FloatingActionButton.extended(
            onPressed: _openAdd,
            icon: const Icon(Icons.add),
            label: const Text('Ekle'),
          ),
        2 => FloatingActionButton.extended(
            onPressed: _openAddRecurring,
            icon: const Icon(Icons.add),
            label: const Text('Yeni'),
          ),
        _ => null,
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Grafikler',
          ),
          NavigationDestination(
            icon: Icon(Icons.repeat_outlined),
            selectedIcon: Icon(Icons.repeat_rounded),
            label: 'Tekrarlayanlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
