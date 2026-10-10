import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';

class SystemInfoDevice extends StatefulWidget {
  final Map<String, String> headers;

  const SystemInfoDevice({super.key, required this.headers});

  @override
  State<SystemInfoDevice> createState() => _SystemInfoDeviceState();
}

class _SystemInfoDeviceState extends State<SystemInfoDevice> {
  int _selectedTab = 0; // 0: Specs, 1: EULA
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();

  Map<String, dynamic> _system = {};
  Map<String, dynamic> _hardware = {};
  Map<String, dynamic> _cpu = {};
  Map<String, dynamic> _memory = {};
  List<dynamic> _gpus = [];

  @override
  void initState() {
    super.initState();
    _parseHeaderData();

    // Timer realtime per detik agar jam berdetik layaknya aplikasi .exe
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  void _parseHeaderData() {
    // Tangkap x-pcspec (Base64 encoded JSON)
    final rawPcSpec =
        widget.headers['x-pcspec'] ?? widget.headers['x-spec'] ?? '';
    if (rawPcSpec.isNotEmpty) {
      try {
        String decodedString;
        try {
          // Decode Base64 jika di-encode
          decodedString = utf8.decode(
            base64Decode(Uri.decodeComponent(rawPcSpec)),
          );
        } catch (_) {
          decodedString = Uri.decodeComponent(rawPcSpec);
        }

        final decodedJson = jsonDecode(decodedString);
        if (decodedJson is Map<String, dynamic>) {
          setState(() {
            _system = decodedJson['system'] as Map<String, dynamic>? ?? {};
            _hardware = decodedJson['hardware'] as Map<String, dynamic>? ?? {};
            _cpu = _hardware['cpu'] as Map<String, dynamic>? ?? {};
            _memory = _hardware['memory'] as Map<String, dynamic>? ?? {};
            _gpus = _hardware['gpus'] as List<dynamic>? ?? [];
          });
        }
      } catch (e) {
        debugPrint('Error parsing x-pcspec: $e');
      }
    }
  }

  String _formatTwoDigits(int n) => n.toString().padLeft(2, '0');

  String _formatDateTime(DateTime dt) {
    return '${_formatTwoDigits(dt.day)}/${_formatTwoDigits(dt.month)}/${dt.year} '
        '${_formatTwoDigits(dt.hour)}:${_formatTwoDigits(dt.minute)}:${_formatTwoDigits(dt.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final appVersion = widget.headers['x-app-version'] ?? '1.0.9659.13774';
    final publicIp =
        widget.headers['x-publicip'] ??
        '2001:448a:2003:4f57:2cac:5eb0:b9ff:24f2';
    final cid = widget.headers['x-cid'] ?? 'BI5SHACABRZQUhxUVVQ=';
    final deviceId = widget.headers['x-device-id'] ?? '-';
    final webVersion = widget.headers['x-webversion'] ?? '154.0.4258.62';

    final computerName = _system['computer_name'] ?? 'DESKTOP-TRQTTUC';
    final osVersion = _system['windows_version'] ?? 'Windows 11 Pro 24H2';
    final osBuild = _system['windows_build'] ?? '26100 (24H2).9457';
    final osArch =
        _system['architecture'] ??
        'x64 (64-bit OS) - Running 32-bit process (WoW64)';
    final installDate = _system['install_date'] ?? '26/03/2026 01:08:24';

    final cpuName = _cpu['name'] ?? 'Intel(R) Core(TM) i5-6500 CPU @ 3.20GHz';
    final ramTotal = _memory['total_gb'] != null
        ? '${_memory['total_gb']} GB'
        : '15,94 GB';
    final gpuName = _gpus.isNotEmpty
        ? (_gpus[0]['name'] ?? 'NVIDIA GeForce GT 730')
        : 'NVIDIA GeForce GT 730';

    final utcTime = _currentTime.toUtc();

    return Scaffold(
      backgroundColor: const Color(0xFF13151B),
      body: SafeArea(
        child: Column(
          children: [
            // TOP HEADER .EXE STYLE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: const Color(0xFF1A1D26),
              child: Row(
                children: [
                  Image.asset(
                    'assets/IconPurple.png',
                    width: 25,
                    height: 25,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.hub,
                      color: Colors.purpleAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Borneo Schematics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Version: $appVersion - [IDIPv6]: $publicIp - CID: $cid',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    tooltip: 'Tutup & Kembali ke Aplikasi',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // BODY UTAMA: SIDEBAR + CONTENT
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // SIDEBAR KIRI
                  Container(
                    width: 240,
                    color: const Color(0xFF161822),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 10,
                    ),
                    child: Column(
                      children: [
                        _buildSidebarButton(
                          title: 'System Device Spesifications',
                          icon: Icons.memory,
                          isSelected: _selectedTab == 0,
                          onTap: () => setState(() => _selectedTab = 0),
                        ),
                        const SizedBox(height: 8),
                        _buildSidebarButton(
                          title: 'Borneo Software Licensing Terms',
                          icon: Icons.credit_card,
                          isSelected: _selectedTab == 1,
                          onTap: () => setState(() => _selectedTab = 1),
                        ),
                        const Spacer(),
                        Opacity(
                          opacity: 0.6,
                          child: Image.asset(
                            'assets/LogoTermAgreement.png',
                            width: 170,
                            height: 170,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // MAIN VIEW (GRID KARTU SISTEM)
                  Expanded(
                    child: _selectedTab == 0
                        ? SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // TITLE PERANGKAT
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.computer,
                                      size: 40,
                                      color: Colors.blueAccent,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$computerName - Device State & Information',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'SID: $deviceId',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // BARIS 1: GPU, CPU, RAM, WINDOWS SYSTEM
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    final cardWidth =
                                        (constraints.maxWidth - 36) / 4;
                                    return Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        _buildInfoBox(
                                          title: 'Graphics Card',
                                          icon: Icons.check_box_outline_blank,
                                          mainText: gpuName,
                                          footerText: '1,9 GB',
                                          width: cardWidth,
                                        ),
                                        _buildInfoBox(
                                          title: 'Processor',
                                          icon: Icons.check_box_outline_blank,
                                          mainText:
                                              '$cpuName\nCPU Cores: 4\nLogical Processors: 4',
                                          footerText: '3,19 GHz',
                                          width: cardWidth,
                                        ),
                                        _buildInfoBox(
                                          title: 'Installed RAM',
                                          icon: Icons.developer_board,
                                          mainText: 'Total RAM: $ramTotal',
                                          footerText: 'DDR4',
                                          width: cardWidth,
                                        ),
                                        _buildInfoBox(
                                          title: 'Windows System',
                                          icon: Icons.window,
                                          mainText:
                                              '$osVersion\n$osBuild\n$osArch',
                                          footerText: 'ID: $installDate',
                                          width: cardWidth,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),

                                // BARIS 2: WEBVIEW STATE, DATE & TIME, FIRST INSTALL, UTC TIME
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B1E29),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          // Webview State
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Row(
                                                  children: [
                                                    Icon(
                                                      Icons.public,
                                                      size: 14,
                                                      color: Colors.blueAccent,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Webview State',
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'WebVersion: $webVersion',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                const Text(
                                                  'Status: INSTALLED\nMinimum Version Meet: True\nEvergreen: True\n\nMinimum Required: 128.0.2739.79',
                                                  style: TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 10,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Date & Time (Realtime)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Row(
                                                  children: [
                                                    Icon(
                                                      Icons.alarm,
                                                      size: 14,
                                                      color: Colors.blueAccent,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Date & Time',
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatDateTime(_currentTime),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Region: W. Mongolia Standard Time\nCountry: ID\nTime Zone: WIB - Waktu Indonesia Barat (Asia/Jakarta) (UTC+07:00)\nUTC Offset: +07:00\nDaylight Saving: False\nCurrent time: ${_currentTime.toIso8601String().replaceFirst('T', ' ')}',
                                                  style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 10,
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // First App Install
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Row(
                                                  children: [
                                                    Icon(
                                                      Icons.alarm,
                                                      size: 14,
                                                      color: Colors.blueAccent,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'First App Install',
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  installDate,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // UTC Date & Time (Realtime)
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Row(
                                                  children: [
                                                    Icon(
                                                      Icons.alarm,
                                                      size: 14,
                                                      color: Colors.blueAccent,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'UTC Date & Time',
                                                      style: TextStyle(
                                                        color: Colors.white70,
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatDateTime(utcTime),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // // BANNER STATUS HIJAU
                                // Container(
                                //   padding: const EdgeInsets.symmetric(
                                //     horizontal: 14,
                                //     vertical: 10,
                                //   ),
                                //   decoration: BoxDecoration(
                                //     color: const Color(0xFF14241B),
                                //     borderRadius: BorderRadius.circular(6),
                                //     border: Border.all(
                                //       color: Colors.green.withOpacity(0.3),
                                //     ),
                                //   ),
                                //   child: Row(
                                //     children: const [
                                //       Icon(
                                //         Icons.check_box,
                                //         color: Colors.greenAccent,
                                //         size: 18,
                                //       ),
                                //       SizedBox(width: 10),
                                //       Expanded(
                                //         child: Text(
                                //           'The runtime is installed and meets the specified requirements.\nDownload and install WebView     Sync Clock - Date     Get Help',
                                //           style: TextStyle(
                                //             color: Colors.greenAccent,
                                //             fontSize: 11,
                                //             height: 1.4,
                                //           ),
                                //         ),
                                //       ),
                                //       Icon(
                                //         Icons.error,
                                //         color: Colors.greenAccent,
                                //         size: 24,
                                //       ),
                                //     ],
                                //   ),
                                // ),
                              ],
                            ),
                          )
                        : _buildEulaView(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF232738) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.blueAccent : Colors.white60,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white60,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBox({
    required String title,
    required IconData icon,
    required String mainText,
    required String footerText,
    required double width,
  }) {
    return Container(
      width: width,
      height: 140,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1E29),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              mainText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                height: 1.3,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            footerText,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildEulaView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER JUDUL
            const Text(
              'Terms & Conditions of Product Use',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Legal Notice & License Agreement',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Divider(color: Colors.white12, height: 24),

            // SECTION 1: ENGLISH
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ENGLISH',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Each activated product is intended solely for registered individual users (personal use). This product is not intended for corporate, enterprise, institutional, or multi-user use unless otherwise expressly agreed in writing under a separate agreement.\n\n'
              'Access to and use of the product are granted based on the selected subscription package:\n'
              '  • Single-user: intended for use on one device.\n'
              '  • Double-user: intended for use on up to two devices.\n\n'
              'Users are not permitted to share account access beyond the number of users or devices allowed under their subscription plan, use the same account simultaneously on more devices than permitted, or allow any third party to access the product.\n\n'
              'Users may not rent, lend, resell, sublicense, transfer, or otherwise distribute access to the product to any third party without our prior written consent.\n\n'
              'Device replacement (device reset) is available only under certain conditions and is subject to limitations. Requests for device replacement must be submitted by the registered user and will be processed in accordance with our applicable policies. We reserve the right to approve or reject such requests to maintain security and ensure proper use of the product.\n\n'
              'If any use is found to be inconsistent with these Terms & Conditions, including but not limited to unauthorized account sharing, exceeding the permitted number of users or devices, or misuse of the device replacement facility, we reserve the right to suspend or terminate the subscription at our sole discretion. Such action may be taken without any obligation to provide a refund for any remaining subscription period.\n\n'
              'This product may only be used for personal purposes as described above. Borneo Schematics designates Hardware Solutions as its primary product. Any additional content provided is intended solely to support the use of the primary product and shall not be considered a separate product or service.\n\n'
              'With respect to content that is not part of the Hardware Solutions product, Borneo Schematics acts solely as a reference provider. Such content is included to support the practical needs of technicians in performing their work, while all rights, policies, and governance remain under the ownership and control of the respective third-party brands.\n\n'
              'All trademarks, device models, trade names, logos, and technical references mentioned within this schematic library are the property and copyright of their respective owners and are used solely for technical reference purposes related to identification, diagnostics, and repair.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.6,
              ),
            ),

            const Divider(color: Colors.white12, height: 32),

            // SECTION 2: BAHASA INDONESIA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'BAHASA INDONESIA',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Setiap produk yang telah diaktivasi hanya diperuntukkan bagi pengguna individual (personal use) yang terdaftar. Produk ini tidak ditujukan untuk penggunaan korporat, enterprise, institusional, atau multi-user, kecuali dinyatakan lain secara tertulis melalui perjanjian terpisah.\n\n'
              'Hak akses dan penggunaan produk diberikan berdasarkan paket langganan yang dipilih:\n'
              '  • Single-user: diperuntukkan untuk penggunaan pada satu perangkat.\n'
              '  • Double-user: diperuntukkan untuk penggunaan pada hingga dua perangkat.\n\n'
              'Pengguna tidak diperkenankan membagikan akses akun melebihi jumlah pengguna atau perangkat yang diizinkan dalam paket langganannya, menggunakan akun secara bersamaan pada perangkat yang melebihi batas yang ditentukan, maupun mengizinkan pihak ketiga mengakses produk ini.\n\n'
              'Pengguna tidak diperkenankan menyewakan, meminjamkan, menjual kembali, mensublisensikan, mengalihkan, atau mendistribusikan hak akses produk kepada pihak lain dalam bentuk apa pun tanpa persetujuan tertulis dari kami.\n\n'
              'Penggantian perangkat (device reset) hanya dapat dilakukan dalam kondisi tertentu dan bersifat terbatas. Permohonan penggantian perangkat harus diajukan oleh pengguna terdaftar dan akan diproses sesuai dengan kebijakan yang berlaku. Kami berhak menyetujui atau menolak permohonan tersebut demi menjaga keamanan serta memastikan penggunaan produk yang semestinya.\n\n'
              'Apabila ditemukan penggunaan yang tidak sesuai dengan ketentuan ini, termasuk namun tidak terbatas pada berbagi akses akun tanpa izin, penggunaan melebihi jumlah pengguna atau perangkat yang diperbolehkan, maupun penyalahgunaan fasilitas penggantian perangkat, kami berhak menghentikan layanan atau mengakhiri langganan secara sepihak. Tindakan tersebut dapat dilakukan tanpa kewajiban pengembalian dana (refund) atas sisa masa berlangganan yang masih berjalan.\n\n'
              'Produk ini hanya boleh digunakan untuk keperluan pribadi sebagaimana dimaksud di atas. Borneo Schematics menetapkan Hardware Solutions sebagai produk utama. Konten tambahan yang disertakan hanya bertujuan mendukung penggunaan produk utama dan tidak dimaksudkan untuk dianggap sebagai produk atau layanan yang berdiri sendiri.\n\n'
              'Terkait konten yang bukan merupakan bagian dari produk Hardware Solutions, Borneo Schematics hanya bertindak sebagai penyedia referensi. Konten tersebut disertakan untuk mendukung kebutuhan praktis teknisi dalam menjalankan pekerjaannya, sementara seluruh hak, kebijakan, dan pengelolaannya tetap berada di bawah kepemilikan serta kewenangan masing-masing merek pihak ketiga yang terkait.\n\n'
              'Seluruh merek, model perangkat, nama dagang, logo, serta referensi teknis yang disebutkan di dalam library skematik ini merupakan milik dan hak cipta dari masing-masing pemegang haknya, dan digunakan semata-mata sebagai referensi teknis untuk keperluan identifikasi, diagnosis, dan perbaikan.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
