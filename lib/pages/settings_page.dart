import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import '../main.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onDeleteAll;
  const SettingsPage({Key? key, required this.onDeleteAll}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // bool _darkMode = false;
  // bool _compactView = false;
  // String _language = 'Indonesia';
  String _defaultPriority = 'Medium';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // _darkMode = prefs.getBool('darkMode') ?? false;
      // _compactView = prefs.getBool('compactView') ?? false;
      // _language = prefs.getString('language') ?? 'Indonesia';
      _defaultPriority = prefs.getString('defaultPriority') ?? 'Medium';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) prefs.setBool(key, value);
    if (value is String) prefs.setString(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── SECTION: Tampilan ──
          // _sectionHeader('Tampilan'),
          // _settingsCard([
          //   _switchTile(
          //     icon: Icons.dark_mode_outlined,
          //     iconColor: const Color(0xFF5C6BC0),
          //     title: 'Dark Mode',
          //     subtitle: 'Ubah tema ke gelap',
          //     value: _darkMode,
          //     onChanged: (v) {
          //       setState(() => _darkMode = v);
          //       _saveSetting('darkMode', v);
          //       TodoApp.of(context)?.setTheme(v);
          //     },
          //   ),
          //   const Divider(height: 1, indent: 56),
          //   _switchTile(
          //     icon: Icons.view_compact_outlined,
          //     iconColor: const Color(0xFF26A69A),
          //     title: 'Tampilan Kompak',
          //     subtitle: 'Perkecil ukuran kartu tugas',
          //     value: _compactView,
          //     onChanged: (v) {
          //       setState(() => _compactView = v);
          //       _saveSetting('compactView', v);
          //     },
          //   ),
          // ]),

          // const SizedBox(height: 16),

          // ── SECTION: Preferensi ──
          _sectionHeader('Preferensi'),
          _settingsCard([
            // _dropdownTile(
            //   icon: Icons.language_outlined,
            //   iconColor: const Color(0xFF4CAF8D),
            //   title: 'Bahasa',
            //   value: _language,
            //   items: ['Indonesia', 'English'],
            //   onChanged: (v) {
            //     setState(() => _language = v!);
            //     _saveSetting('language', v!);
            //   },
            // ),
            // const Divider(height: 1, indent: 56),
            _dropdownTile(
              icon: Icons.flag_outlined,
              iconColor: const Color(0xFFFF7043),
              title: 'Prioritas Default',
              value: _defaultPriority,
              items: ['Low', 'Medium', 'High', 'Urgent'],
              onChanged: (v) {
                setState(() => _defaultPriority = v!);
                _saveSetting('defaultPriority', v!);
              },
            ),
          ]),

          const SizedBox(height: 16),

          // ── SECTION: Data ──
          _sectionHeader('Data'),
          _settingsCard([
            _arrowTile(
              icon: Icons.backup_outlined,
              iconColor: const Color(0xFF42A5F5),
              title: 'Backup Data',
              subtitle: 'Simpan data ke penyimpanan lokal',
              onTap: () => _showSnackbar('Fitur backup akan segera hadir'),
            ),
            const Divider(height: 1, indent: 56),
            _arrowTile(
              icon: Icons.delete_sweep_outlined,
              iconColor: const Color(0xFFEF5350),
              title: 'Hapus Semua Task',
              subtitle: 'Tindakan ini tidak bisa dibatalkan',
              onTap: () => _showDeleteConfirm(),
            ),
          ]),

          const SizedBox(height: 16),

          // ── SECTION: Tentang ──
          _sectionHeader('Tentang'),
          _settingsCard([
            _arrowTile(
              icon: Icons.info_outline,
              iconColor: const Color(0xFF4CAF8D),
              title: 'Versi Aplikasi',
              subtitle: 'TaskFlow v1.0.0',
              onTap: null,
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── WIDGETS HELPER ──────────────────────────────────

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.black45,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _settingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  // Widget _switchTile({
  //   required IconData icon,
  //   required Color iconColor,
  //   required String title,
  //   required String subtitle,
  //   required bool value,
  //   required Function(bool) onChanged,
  // }) {
  //   return ListTile(
  //     leading: _iconBox(icon, iconColor),
  //     title: Text(title,
  //         style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
  //     subtitle: Text(subtitle,
  //         style: const TextStyle(fontSize: 12, color: Colors.black45)),
  //     trailing: Switch(
  //       value: value,
  //       onChanged: onChanged,
  //       activeColor: const Color(0xFF4CAF8D),
  //       materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  //     ),
  //   );
  // }

  Widget _dropdownTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return ListTile(
      leading: _iconBox(icon, iconColor),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      trailing: DropdownButton<String>(
        value: value,
        isDense: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.keyboard_arrow_down, size: 18),
        items: items
            .map((e) => DropdownMenuItem(
                value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _arrowTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      leading: _iconBox(icon, iconColor),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: Colors.black45)),
      trailing: onTap != null
          ? const Icon(Icons.chevron_right, color: Colors.black26)
          : null,
      onTap: onTap,
    );
  }

  Widget _iconBox(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showDeleteConfirm() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Semua Task?'),
        content: const Text(
            'Semua task akan dihapus permanen dan tidak bisa dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDeleteAll();
              _showSnackbar('Semua task berhasil dihapus');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
