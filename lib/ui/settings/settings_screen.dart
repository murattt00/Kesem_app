import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../providers.dart';
import '../theme/app_theme.dart';
import 'category_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider).value ?? ThemeMode.system;
    return ListView(
      children: [
        _header(context, 'Görünüm'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Sistem'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Açık'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Koyu'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              final m = s.first;
              final str = m == ThemeMode.light
                  ? 'light'
                  : m == ThemeMode.dark
                      ? 'dark'
                      : 'system';
              ref.read(settingsRepoProvider).setValue('themeMode', str);
            },
          ),
        ),
        const Divider(),
        _header(context, 'Yedekleme'),
        ListTile(
          leading: const Icon(Icons.file_upload_outlined),
          title: const Text('Yedeği dışa aktar (JSON)'),
          subtitle: const Text('Tüm verini tek dosyada paylaş/kaydet'),
          onTap: () => _exportJson(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.file_download_outlined),
          title: const Text('Yedekten geri yükle (JSON)'),
          subtitle: const Text('Mevcut veriyi yedekle değiştirir'),
          onTap: () => _importJson(context, ref),
        ),
        ListTile(
          leading: const Icon(Icons.table_chart_outlined),
          title: const Text('İşlemleri CSV olarak ver'),
          subtitle: const Text('Excel / Google Sheets için'),
          onTap: () => _exportCsv(context, ref),
        ),
        const Divider(),
        _header(context, 'Kategoriler'),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: const Text('Kategori yönetimi'),
          subtitle: const Text('Özel kategori ekle, düzenle, arşivle'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CategoryScreen()),
          ),
        ),
        const Divider(),
        _header(context, 'Hakkında'),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Kesem'),
          subtitle: Text('Sürüm 1.0.0 · Verilerin telefonunda kalır'),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: context.scheme.primary,
          ),
        ),
      );

  String _stamp() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${two(n.month)}${two(n.day)}_${two(n.hour)}${two(n.minute)}';
  }

  Future<void> _shareFile(String content, String filename, String subject) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(content);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject),
    );
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await ref.read(backupServiceProvider).exportJson();
      await _shareFile(
        json,
        'kesem_yedek_${_stamp()}.json',
        'Kesem Yedeği',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final csv = await ref.read(backupServiceProvider).exportCsv();
      await _shareFile(
        csv,
        'kesem_islemler_${_stamp()}.csv',
        'Kesem İşlemleri',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _importJson(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    const group = XTypeGroup(label: 'Yedek', extensions: ['json']);
    final picked = await openFile(acceptedTypeGroups: [group]);
    if (picked == null) return;
    final content = await picked.readAsString();

    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Geri yüklensin mi?'),
        content: const Text(
          'Mevcut TÜM verin silinip yedektekiyle değiştirilecek. '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Geri yükle'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final s = await ref.read(backupServiceProvider).importJson(content);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Geri yüklendi: ${s.transactions} işlem, '
            '${s.recurring} tekrarlayan, ${s.categories} kategori',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Geri yükleme başarısız: $e')),
      );
    }
  }
}
