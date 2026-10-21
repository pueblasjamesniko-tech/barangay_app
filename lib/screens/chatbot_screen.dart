import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/api.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../services/repo.dart';
import '../widgets/common.dart';

class _Msg {
  final String text;
  final bool fromBot;
  const _Msg(this.text, this.fromBot);
}

/// Button-based FAQ chatbot. Questions and answers come from GET /api/ChatbotFaq,
/// which the admin manages in the web panel.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [
    const _Msg(
        'Hi! I am the barangay helper. Tap a question below and I will answer it.',
        true),
  ];
  List<Faq>? _faqs;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final l = await Repo.faqs();
      if (!mounted) return;
      setState(() {
        _faqs = l;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error =
          e is ApiException ? e.message : 'Could not load the questions.');
    }
  }

  void _ask(Faq f) {
    setState(() {
      _msgs.add(_Msg(f.question, false));
      _msgs.add(_Msg(f.answer, true));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          TabHeader(
            title: 'Help & FAQ',
            subtitle: 'Barangay ${AppConfig.barangayName} helper',
            onBack: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _msgs.length,
              itemBuilder: (_, i) => _bubble(_msgs[i]),
            ),
          ),
          SafeArea(top: false, child: _suggestions()),
        ],
      ),
    );
  }

  Widget _suggestions() {
    if (_faqs == null && _error == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_faqs == null) {
      return ErrorState(message: _error!, onRetry: _load);
    }
    if (_faqs!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No questions have been added yet.',
            style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.muted)),
      );
    }
    return Container(
      constraints: const BoxConstraints(maxHeight: 190),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in _faqs!)
              ActionChip(
                backgroundColor: AppColors.softBlue,
                side: BorderSide.none,
                label: Text(f.question,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.navy)),
                onPressed: () => _ask(f),
              ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(_Msg m) {
    final bot = m.fromBot;
    return Align(
      alignment: bot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bot ? Colors.white : AppColors.navy,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(bot ? 4 : 16),
            bottomRight: Radius.circular(bot ? 16 : 4),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Text(
          m.text,
          style: GoogleFonts.poppins(
              fontSize: 13, height: 1.4, color: bot ? AppColors.text : Colors.white),
        ),
      ),
    );
  }
}
