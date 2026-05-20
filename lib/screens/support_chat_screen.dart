import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _orderNoController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'text':
          'Merhaba! Ben Vitrin destek asistanıyım. Kargo takibi, iade, iptal ve müşteri hizmetleri konularında yardımcı olabilirim. İstersen sipariş numaranı da yazabilirsin.'
    }
  ];

  bool _isSending = false;
  bool _stylistMode = false;
  String _occasion = 'Günlük';
  String _weather = 'Ilık';
  List<String> _suggestions = const [
    'Kargom nerede?',
    'İade nasıl yaparım?',
    'Sipariş iptali mümkün mü?',
    'Canlı desteğe nasıl bağlanırım?'
  ];

  static const List<String> _supportSuggestions = [
    'Kargom nerede?',
    'İade nasıl yaparım?',
    'Sipariş iptali mümkün mü?',
    'Canlı desteğe nasıl bağlanırım?'
  ];

  static const List<String> _stylistSuggestions = [
    'Bugün iş görüşmem var, ne giymeliyim?',
    'Bu eteğin üstüne ne gider?',
    'Hava serin, rahat ama şık kombin öner',
    'Siyah pantolonla 2 alternatif çıkar'
  ];

  static const List<String> _occasionOptions = [
    'Günlük',
    'Ofis',
    'İş Görüşmesi',
    'Akşam',
    'Spor'
  ];

  static const List<String> _weatherOptions = [
    'Sıcak',
    'Ilık',
    'Serin',
    'Soğuk',
    'Yağmurlu'
  ];

  void _switchMode(bool stylistMode) {
    if (_isSending) return;

    setState(() {
      _stylistMode = stylistMode;
      _messages
        ..clear()
        ..add({
          'role': 'assistant',
          'text': stylistMode
              ? 'Merhaba! Ben Vitrin AI stil asistanıyım. Gardırobundaki parçalarla sana kombin önerebilirim.'
              : 'Merhaba! Ben Vitrin destek asistanıyım. Kargo takibi, iade, iptal ve müşteri hizmetleri konularında yardımcı olabilirim. İstersen sipariş numaranı da yazabilirsin.'
        });
      _suggestions = stylistMode ? _stylistSuggestions : _supportSuggestions;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _orderNoController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? preset]) async {
    if (_isSending) return;

    final raw = preset ?? _messageController.text;
    final text = raw.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isSending = true;
    });
    _messageController.clear();
    _scrollToBottom();

    try {
      final history = _messages
          .map((m) => {
                'role': m['role'] ?? 'user',
                'text': m['text'] ?? '',
              })
          .toList();

      final activeResult = _stylistMode
          ? await ApiService.stylistChat(
              message: text,
              history: history,
              occasion: _occasion,
              weather: _weather,
            )
          : await ApiService.supportChat(
              message: text,
              history: history,
              orderNo: _orderNoController.text,
            );

      final reply = (activeResult['reply'] ?? '').toString().trim();
      final suggestionsRaw = activeResult['suggestions'];
      final nextSuggestions = suggestionsRaw is List
          ? suggestionsRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : _suggestions;

      setState(() {
        _messages.add({
          'role': 'assistant',
          'text': reply.isNotEmpty
              ? reply
              : 'Şu an yanıt üretilemedi. Lütfen tekrar deneyin.'
        });
        _suggestions = nextSuggestions;
      });
    } catch (_) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'text':
              'Bağlantı sorunu oluştu. Lütfen kısa süre sonra tekrar deneyin.'
        });
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F0),
      appBar: AppBar(
        title: const Text(
          'AI Asistan',
          style: TextStyle(color: Color(0xFF2D2D2D), fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D2D2D)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Destek'),
                    selected: !_stylistMode,
                    onSelected: (_) => _switchMode(false),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('AI Stilist'),
                    selected: _stylistMode,
                    onSelected: (_) => _switchMode(true),
                  ),
                ),
              ],
            ),
          ),
          if (!_stylistMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _orderNoController,
              decoration: InputDecoration(
                hintText: 'Sipariş No (opsiyonel)',
                prefixIcon: const Icon(Icons.receipt_long),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                ),
              ),
            ),
          ),
          if (_stylistMode)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Stilist modu gardırobundaki ürünlerle kombin önerir.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF777777)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _occasion,
                          items: _occasionOptions
                              .map(
                                (o) => DropdownMenuItem(
                                  value: o,
                                  child: Text(o),
                                ),
                              )
                              .toList(),
                          onChanged: _isSending
                              ? null
                              : (v) => setState(() => _occasion = v ?? _occasion),
                          decoration: InputDecoration(
                            labelText: 'Ortam',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE8E8E8)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _weather,
                          items: _weatherOptions
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w,
                                  child: Text(w),
                                ),
                              )
                              .toList(),
                          onChanged: _isSending
                              ? null
                              : (v) => setState(() => _weather = v ?? _weather),
                          decoration: InputDecoration(
                            labelText: 'Hava',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFFE8E8E8)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _suggestions
                    .map(
                      (s) => ActionChip(
                        label: Text(s),
                        onPressed: _isSending ? null : () => _sendMessage(s),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFE8E8E8)),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final item = _messages[index];
                final isUser = item['role'] == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? const Color(0xFF2D2D2D) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: isUser
                          ? null
                          : Border.all(color: const Color(0xFFE8E8E8)),
                    ),
                    child: Text(
                      item['text'] ?? '',
                      style: TextStyle(
                        color: isUser ? Colors.white : const Color(0xFF2D2D2D),
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: _stylistMode
                            ? 'Mesaj yaz (ör: Bu etekle ne giyebilirim?)'
                            : 'Sorunu yaz (kargo, iade, iptal...)',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _sendMessage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D2D2D),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
