import 'package:flutter/material.dart';

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({Key? key}) : super(key: key);

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  int? _expandedIndex;

  final List<Map<String, String>> _faqs = [
    {
      'q': 'Bagaimana cara membuat task baru?',
      'a': 'Tekan tombol + (hijau) di pojok kanan bawah halaman Boards. Isi judul task, pilih prioritas, due date, dan fitur lainnya sesuai kebutuhan.',
    },
    {
      'q': 'Apa bedanya status Open, In Progress, dan Done?',
      'a': 'Open: task belum dikerjakan. In Progress: task sedang dikerjakan. Done: task sudah selesai. Kamu bisa ubah status dengan menekan ikon titik tiga di kartu task.',
    },
    {
      'q': 'Bagaimana cara mengatur pengingat (reminder)?',
      'a': 'Saat membuat atau mengedit task, aktifkan toggle Reminder lalu pilih jam yang diinginkan. Pengingat akan muncul sesuai waktu yang diatur.',
    },
    {
      'q': 'Apa itu Recurring Task?',
      'a': 'Recurring task adalah tugas yang berulang secara otomatis. Pilih jenis pengulangan: Daily (harian), Weekly (mingguan), Monthly (bulanan), atau Yearly (tahunan).',
    },
    {
      'q': 'Bagaimana cara menambah subtask?',
      'a': 'Di halaman tambah/edit task, tekan tombol "Add Subtask". Masukkan nama subtask lalu tekan Add. Kamu bisa menambahkan sebanyak yang dibutuhkan.',
    },
    {
      'q': 'Apakah data tersimpan otomatis?',
      'a': 'Ya, semua data tersimpan otomatis setiap kali kamu membuat, mengubah, atau menghapus task. Data tidak akan hilang meski aplikasi ditutup.',
    },
    {
      'q': 'Bagaimana cara melihat task berdasarkan tanggal?',
      'a': 'Buka halaman Schedule (ikon kalender di navbar bawah). Pilih tanggal yang ingin dilihat, semua task dengan due date pada hari itu akan tampil di timeline.',
    },
  ];

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
          'Help & Support',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF8D), Color(0xFF2E7D5E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Ada yang bisa kami bantu?',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Temukan jawaban di FAQ atau hubungi kami',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.support_agent,
                    color: Colors.white70, size: 48),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // FAQ
          _sectionHeader('Pertanyaan Umum (FAQ)'),
          Container(
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
            child: Column(
              children: _faqs.asMap().entries.map((entry) {
                final i = entry.key;
                final faq = entry.value;
                final isExpanded = _expandedIndex == i;
                return Column(
                  children: [
                    ListTile(
                      title: Text(
                        faq['q']!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isExpanded
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isExpanded
                              ? const Color(0xFF4CAF8D)
                              : Colors.black,
                        ),
                      ),
                      trailing: AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down,
                            color: Colors.black38),
                      ),
                      onTap: () => setState(() {
                        _expandedIndex = isExpanded ? null : i;
                      }),
                    ),
                    AnimatedCrossFade(
                      firstChild: const SizedBox(width: double.infinity),
                      secondChild: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Text(
                          faq['a']!,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                              height: 1.6),
                        ),
                      ),
                      crossFadeState: isExpanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                    if (i < _faqs.length - 1)
                      const Divider(height: 1, indent: 16),
                  ],
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 20),

          // Kontak
          _sectionHeader('Hubungi Kami'),
          _contactCard(
            icon: Icons.email_outlined,
            iconColor: const Color(0xFF42A5F5),
            title: 'Email Support',
            subtitle: 'support@taskflow.app',
            onTap: () => _showSnackbar('Membuka email...'),
          ),
          const SizedBox(height: 10),
          _contactCard(
            icon: Icons.chat_bubble_outline,
            iconColor: const Color(0xFF4CAF8D),
            title: 'Live Chat',
            subtitle: 'Senin–Jumat, 09:00–17:00',
            onTap: () => _showSnackbar('Fitur live chat segera hadir'),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

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

  Widget _contactCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: Colors.black45, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}