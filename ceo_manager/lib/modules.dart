import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';
import 'widgets.dart';

// Shared section header inside a scrolling module body.
Widget _eyebrow(BuildContext context, String text) {
  final c = SfTheme.of(context);
  return Padding(
    padding: const EdgeInsets.fromLTRB(2, 4, 0, 8),
    child: Text(text.toUpperCase(),
        style: TextStyle(
            fontFamily: SfType.ui, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.9, color: c.muted)),
  );
}

const _mPad = EdgeInsets.fromLTRB(16, 14, 16, 24);

// ════════════════════════════════════════════════════════════════════════
// 1. Payments — Click / Payme / Uzum / Naqd
// ════════════════════════════════════════════════════════════════════════
class _Pay {
  final String who;
  final num amount;
  final String channel;
  final String time;
  final bool ok; // ok | pending
  const _Pay(this.who, this.amount, this.channel, this.time, {this.ok = true});
}

const _payments = [
  _Pay('Azizova Madina', 600000, 'Payme', '09:14'),
  _Pay('Halimova Zilola', 600000, 'Click', '09:02'),
  _Pay('Ibragimov Sardor', 600000, 'Naqd', 'Kecha'),
  _Pay("G'aniyev Jasur", 300000, 'Uzum', 'Kecha', ok: false),
  _Pay('Davronova Sevinch', 600000, 'Payme', '2 kun'),
];

class PaymentsScreen extends StatefulWidget {
  final SfColors colors;
  const PaymentsScreen({super.key, required this.colors});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  static const _filters = ['Hammasi', 'Click', 'Payme', 'Uzum', 'Naqd'];
  int sel = 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final list = sel == 0 ? _payments : _payments.where((p) => p.channel == _filters[sel]).toList();
    final collected = _payments.where((p) => p.ok).fold<num>(0, (s, p) => s + p.amount);
    return SfScaffold(
      colors: c,
      title: "To'lovlar",
      body: ListView(
        padding: _mPad,
        children: [
          Row(children: [
            Expanded(child: SfStatTile('Bugun yig‘ildi', fmtMoneyShort(collected), c.success)),
            const SizedBox(width: 10),
            Expanded(child: SfStatTile('Qarzdorlik', '84m', c.danger)),
            const SizedBox(width: 10),
            Expanded(child: SfStatTile("To'lovlar", '${_payments.length}', c.ink)),
          ]),
          const SizedBox(height: 14),
          SfSelectChips(items: _filters, selected: sel, onSelect: (i) => setState(() => sel = i)),
          const SizedBox(height: 12),
          SfCard(
            child: Column(children: [
              const SfCardHeader('So‘nggi to‘lovlar'),
              for (int i = 0; i < list.length; i++)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  decoration: BoxDecoration(
                      border: Border(bottom: i < list.length - 1 ? BorderSide(color: c.border) : BorderSide.none)),
                  child: Row(children: [
                    SfAvatar(name: list[i].who, size: 34),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(list[i].who,
                            style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(5)),
                            child: Text(list[i].channel,
                                style: TextStyle(fontFamily: SfType.ui, fontSize: 9.5, fontWeight: FontWeight.w700, color: c.ink2)),
                          ),
                          const SizedBox(width: 6),
                          Text(list[i].time, style: TextStyle(fontFamily: SfType.ui, fontSize: 10, color: c.muted)),
                        ]),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('+${fmtMoneyShort(list[i].amount)}',
                          style: TextStyle(fontFamily: SfType.mono, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.success)),
                      Pill(list[i].ok ? 'Qabul' : 'Kutilmoqda', tone: list[i].ok ? PillTone.success : PillTone.warn),
                    ]),
                  ]),
                ),
            ]),
          ),
        ],
      ),
      bottomBar: _bottomBar(
        context,
        c,
        SfButton(
          icon: Icons.add_rounded,
          label: "To'lov qabul qilish",
          primary: true,
          onTap: () => sfSnack(context, "💳 To'lov qabul qilish (Click/Payme demo)", bg: const Color(0xFF4F7B3B)),
        ),
      ),
    );
  }
}

// Shared bottom action bar.
Widget _bottomBar(BuildContext context, SfColors c, Widget child) => Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: c.surface, border: Border(top: BorderSide(color: c.border))),
      child: SizedBox(width: double.infinity, child: child),
    );

// ════════════════════════════════════════════════════════════════════════
// 2. Printing — queue, layouts, paper accounting
// ════════════════════════════════════════════════════════════════════════
class _PrintJob {
  final String title;
  final String who;
  final int pages;
  final int copies;
  final String layout;
  const _PrintJob(this.title, this.who, this.pages, this.copies, this.layout);
}

const _printJobs = [
  _PrintJob('Grammar Unit 7', 'Nigora K.', 4, 18, '2-up · duplex'),
  _PrintJob('IELTS Listening', 'Aziz T.', 6, 24, 'duplex'),
  _PrintJob('Vocabulary set', 'Nigora K.', 2, 30, '2-up'),
  _PrintJob('Mock test #3', 'Qabul', 12, 15, 'duplex'),
];

class PrintingScreen extends StatelessWidget {
  final SfColors colors;
  const PrintingScreen({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final totalPages = _printJobs.fold<int>(0, (s, j) => s + j.pages * j.copies);
    return SfScaffold(
      colors: c,
      title: 'Bosib chiqarish',
      body: ListView(
        padding: _mPad,
        children: [
          Row(children: [
            Expanded(child: SfStatTile('Bu oy · varaq', '$totalPages', c.ink)),
            const SizedBox(width: 10),
            Expanded(child: SfStatTile('Tejaldi · 2-up', '~38%', c.success)),
            const SizedBox(width: 10),
            Expanded(child: SfStatTile('Navbatda', '${_printJobs.length}', c.warn)),
          ]),
          const SizedBox(height: 14),
          _eyebrow(context, 'Bosib chiqarish navbati'),
          SfCard(
            child: Column(children: [
              for (int i = 0; i < _printJobs.length; i++)
                Builder(builder: (context) {
                  final j = _printJobs[i];
                  return Container(
                    padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                    decoration: BoxDecoration(
                        border: Border(bottom: i < _printJobs.length - 1 ? BorderSide(color: c.border) : BorderSide.none)),
                    child: Row(children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.print_rounded, size: 17, color: c.primary),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(j.title,
                              style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                          Text('${j.who} · ${j.layout}',
                              style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                        ]),
                      ),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${j.pages * j.copies} v.',
                            style: TextStyle(fontFamily: SfType.mono, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.ink)),
                        Text('${j.copies}×${j.pages}', style: TextStyle(fontFamily: SfType.ui, fontSize: 9.5, color: c.muted)),
                      ]),
                    ]),
                  );
                }),
            ]),
          ),
          const SizedBox(height: 6),
          Text('Har bir ish xodimga biriktiriladi — qog‘oz sarfi ko‘rinadi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted2)),
        ],
      ),
      bottomBar: _bottomBar(
        context,
        c,
        SfButton(
          icon: Icons.add_rounded,
          label: 'Yangi bosib chiqarish ishi',
          primary: true,
          onTap: () => sfSnack(context, '🖨️ Yangi ish navbatga qo‘shildi (demo)'),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 3. Mock exams — AI auto-scoring
// ════════════════════════════════════════════════════════════════════════
class ExamsScreen extends StatelessWidget {
  final SfColors colors;
  const ExamsScreen({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final exams = [
      ('IELTS Academic · Full', 'AI + rasmiy', '2 soat 45 daq', true),
      ('CEFR B2 · Reading', 'AI generatsiya', '60 daqiqa', true),
      ('IELTS Writing Task 2', 'AI baholash', '40 daqiqa', true),
      ('Listening · Set 4', 'Rasmiy', '30 daqiqa', false),
    ];
    return SfScaffold(
      colors: c,
      title: 'Mock imtihonlar',
      body: ListView(
        padding: _mPad,
        children: [
          // AI auto-scoring showcase
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: c.aiBg, begin: Alignment.topLeft, end: Alignment.bottomRight),
              border: Border.all(color: c.aiBorder),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SfAiBadge('AI baholash'),
                const Spacer(),
                Text('Band 7.0',
                    style: TextStyle(fontFamily: SfType.mono, fontSize: 20, fontWeight: FontWeight.w700, color: c.ai)),
              ]),
              const SizedBox(height: 10),
              for (final b in const [
                ('Task Response', '7.5'),
                ('Coherence', '7.0'),
                ('Lexical', '6.5'),
                ('Grammar', '7.0'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(
                        child: Text(b.$1, style: TextStyle(fontFamily: SfType.ui, fontSize: 12, color: c.ink2))),
                    Text(b.$2,
                        style: TextStyle(fontFamily: SfType.mono, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.ink)),
                  ]),
                ),
              const SizedBox(height: 8),
              Text('“Kuchli argument, ammo ba’zi bog‘lovchilar takrorlangan…”',
                  style: TextStyle(fontFamily: SfType.display, fontStyle: FontStyle.italic, fontSize: 13.5, color: c.ink)),
            ]),
          ),
          const SizedBox(height: 16),
          _eyebrow(context, 'Mavjud imtihonlar'),
          for (final e in exams)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(13)),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: (e.$4 ? c.ai : c.muted).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(11)),
                  child: Icon(e.$4 ? Icons.auto_awesome_rounded : Icons.description_rounded,
                      size: 18, color: e.$4 ? c.ai : c.muted),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.$1, style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w700, color: c.ink)),
                    Text('${e.$2} · ${e.$3}', style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                  ]),
                ),
                GestureDetector(
                  onTap: () => sfSnack(context, '📝 "${e.$1}" boshlandi (demo)'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(9)),
                    child: Text('Boshlash',
                        style: TextStyle(fontFamily: SfType.ui, fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 4. AI speaking partner — IELTS speaking simulator
// ════════════════════════════════════════════════════════════════════════
class SpeakingScreen extends StatefulWidget {
  final SfColors colors;
  const SpeakingScreen({super.key, required this.colors});
  @override
  State<SpeakingScreen> createState() => _SpeakingScreenState();
}

class _SpeakingScreenState extends State<SpeakingScreen> {
  bool started = false;
  static const _turns = [
    (false, 'Let’s talk about your hometown. Where are you from?'),
    (true, 'I’m from Namangan, a city in the east of Uzbekistan.'),
    (false, 'What do you like most about living there?'),
    (true, 'The people are very warm, and the food is amazing.'),
    (false, 'Now, describe a skill you would like to learn. You have one minute.'),
    (true, 'I’d like to learn how to edit videos, because…'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SfScaffold(
      colors: c,
      title: 'AI suhbatdosh',
      body: ListView(
        padding: _mPad,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.record_voice_over_rounded, size: 22, color: c.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('IELTS Speaking simulyatori',
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 14, fontWeight: FontWeight.w800, color: c.ink)),
                  Text('3 qism · 24/7 · darhol band baho',
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 11, color: c.muted)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          if (!started) ...[
            for (final p in const [
              ('1-qism', 'Interview · tanishuv savollari'),
              ('2-qism', 'Cue card · 2 daqiqa monolog'),
              ('3-qism', 'Discussion · chuqurroq muhokama'),
            ])
              Container(
                margin: const EdgeInsets.only(bottom: 9),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                    color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Text(p.$1,
                      style: TextStyle(fontFamily: SfType.mono, fontSize: 12, fontWeight: FontWeight.w700, color: c.primary)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p.$2, style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, color: c.ink2))),
                ]),
              ),
          ] else ...[
            for (final t in _turns)
              Align(
                alignment: t.$1 ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: t.$1 ? null : LinearGradient(colors: c.aiBg),
                    color: t.$1 ? c.primary : null,
                    border: t.$1 ? null : Border.all(color: c.aiBorder),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Text(t.$2,
                      style: TextStyle(
                          fontFamily: t.$1 ? SfType.ui : SfType.display,
                          fontStyle: t.$1 ? FontStyle.normal : FontStyle.italic,
                          fontSize: t.$1 ? 13 : 14,
                          height: 1.3,
                          color: t.$1 ? Colors.white : c.ink)),
                ),
              ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: c.aiBg, begin: Alignment.topLeft, end: Alignment.bottomRight),
                border: Border.all(color: c.aiBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Taxminiy band baho',
                        style: TextStyle(fontFamily: SfType.ui, fontSize: 11, fontWeight: FontWeight.w700, color: c.ai)),
                    Text('Fluency 6.5 · Lexical 7.0 · Grammar 6.5',
                        style: TextStyle(fontFamily: SfType.ui, fontSize: 11, color: c.ink2)),
                    Text('Talaffuz — taxminiy (keyin aniqroq)',
                        style: TextStyle(fontFamily: SfType.ui, fontSize: 10, color: c.muted)),
                  ]),
                ),
                Text('6.5',
                    style: TextStyle(fontFamily: SfType.mono, fontSize: 24, fontWeight: FontWeight.w700, color: c.ai)),
              ]),
            ),
          ],
        ],
      ),
      bottomBar: _bottomBar(
        context,
        c,
        SfButton(
          icon: started ? Icons.refresh_rounded : Icons.mic_rounded,
          label: started ? 'Qaytadan boshlash' : 'Testni boshlash',
          primary: true,
          onTap: () => setState(() => started = !started),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 5. Camera analysis — on-prem lesson insights
// ════════════════════════════════════════════════════════════════════════
class CameraScreen extends StatelessWidget {
  final SfColors colors;
  const CameraScreen({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final rooms = [
      ('101-xona · Algebra', true, 'Tahlil tayyor'),
      ('102-xona · Ingliz', true, 'Tahlil tayyor'),
      ('203-xona · Fizika', false, 'Dars davom etmoqda'),
    ];
    return SfScaffold(
      colors: c,
      title: 'Kamera tahlili',
      body: ListView(
        padding: _mPad,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.successSoft, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.shield_rounded, size: 18, color: c.success),
              const SizedBox(width: 9),
              Expanded(
                child: Text("Edge-box binoda · ma'lumot tashqariga chiqmaydi (biometrik qonun)",
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 11, fontWeight: FontWeight.w600, color: c.success)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          // Lesson analysis report
          SfCard(
            child: Column(children: [
              const SfCardHeader('Dars tahlili · 102-xona'),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Column(children: [
                  _bar(context, 'O‘z vaqtida boshlandi', 1.0, c.success, 'Ha'),
                  _bar(context, 'Mavzu qamrovi', 0.86, c.success, '86%'),
                  _bar(context, 'O‘qituvchi faolligi', 0.74, c.warn, '74%'),
                  _bar(context, 'Ijobiy ohang', 0.92, c.success, '92%'),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Row(children: [
                  Icon(Icons.graphic_eq_rounded, size: 15, color: c.muted),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text('Audio → transkript → mahalliy LLM tahlili',
                        style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                  ),
                ]),
              ),
            ]),
          ),
          _eyebrow(context, 'Xonalar'),
          for (final r in rooms)
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                  color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.videocam_rounded, size: 20, color: r.$2 ? c.success : c.muted),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(r.$1, style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                ),
                Pill(r.$3, tone: r.$2 ? PillTone.success : PillTone.neutral, dot: true),
              ]),
            ),
          Text('Kim ko‘rishini har markaz o‘zi sozlaydi · rozilik + ogohlantirish.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted2)),
        ],
      ),
    );
  }

  Widget _bar(BuildContext context, String label, double v, Color color, String tag) {
    final c = SfTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontFamily: SfType.ui, fontSize: 11.5, color: c.ink2))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
                value: v, minHeight: 7, backgroundColor: c.surface2, valueColor: AlwaysStoppedAnimation(color)),
          ),
        ),
        const SizedBox(width: 9),
        SizedBox(
            width: 36,
            child: Text(tag,
                textAlign: TextAlign.right,
                style: TextStyle(fontFamily: SfType.mono, fontSize: 11, fontWeight: FontWeight.w700, color: c.ink))),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 6. Rewards — points economy + redemption store
// ════════════════════════════════════════════════════════════════════════
class _Reward {
  final String name;
  final int cost;
  final IconData icon;
  const _Reward(this.name, this.cost, this.icon);
}

const _catalog = [
  _Reward('Ruchka · daftar', 150, Icons.edit_rounded),
  _Reward('Stiker to‘plami', 300, Icons.auto_awesome_rounded),
  _Reward('Termokружka', 1200, Icons.local_cafe_rounded),
  _Reward('CMF / Samsung Buds', 9000, Icons.headphones_rounded),
  _Reward('AirPods', 18000, Icons.headphones_rounded),
];

class RewardsScreen extends StatefulWidget {
  final SfColors colors;
  const RewardsScreen({super.key, required this.colors});
  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  int points = 2450;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SfScaffold(
      colors: c,
      title: 'Mukofotlar',
      body: ListView(
        padding: _mPad,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.primary, c.primaryHover], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(children: [
              const SfStar(size: 30, color: Colors.white),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Sizning ballaringiz',
                    style: TextStyle(fontFamily: SfType.ui, fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                Text('$points',
                    style: const TextStyle(fontFamily: SfType.mono, fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          _eyebrow(context, 'Reyting · bu hafta'),
          SfCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: HBars(rows: [
                HBarRow('Madina', 3120, '3120', c.success),
                HBarRow('Siz', 2450, '2450', c.primary),
                HBarRow('Jasur', 1980, '1980', c.accent),
                HBarRow('Sardor', 1600, '1600', c.muted2),
              ]),
            ),
          ),
          _eyebrow(context, 'Do‘kon'),
          for (final r in _catalog)
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: BorderRadius.circular(11)),
                  child: Icon(r.icon, size: 20, color: c.accentInk),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.name, style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w700, color: c.ink)),
                    Text('${r.cost} ball',
                        style: TextStyle(fontFamily: SfType.mono, fontSize: 11, fontWeight: FontWeight.w700, color: c.muted)),
                  ]),
                ),
                _redeemBtn(context, c, r),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _redeemBtn(BuildContext context, SfColors c, _Reward r) {
    final can = points >= r.cost;
    return GestureDetector(
      onTap: can
          ? () {
              setState(() => points -= r.cost);
              sfSnack(context, '🎁 "${r.name}" almashtirildi! (-${r.cost} ball)', bg: const Color(0xFF4F7B3B));
            }
          : () => sfSnack(context, 'Ball yetarli emas · yana ${r.cost - points}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
            color: can ? c.primary : c.surface2,
            border: can ? null : Border.all(color: c.border),
            borderRadius: BorderRadius.circular(9)),
        child: Text('Almashtirish',
            style: TextStyle(
                fontFamily: SfType.ui, fontSize: 11.5, fontWeight: FontWeight.w700, color: can ? Colors.white : c.muted)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 7. HR — staff + hiring pipeline
// ════════════════════════════════════════════════════════════════════════
class HrScreen extends StatelessWidget {
  final SfColors colors;
  const HrScreen({super.key, required this.colors});
  @override
  Widget build(BuildContext context) {
    final c = colors;
    final staff = [
      ('Nigora Karimova', "O'qituvchi · Matematika", '4 yil shartnoma'),
      ('Aziz Tursunov', "O'qituvchi · Ingliz", '2 yil shartnoma'),
      ("Dilnoza Yo'ldosheva", 'Filial menejeri', '3 yil shartnoma'),
      ('Jasur Aliyev', 'Printer operatori', '1 yil shartnoma'),
    ];
    final pipeline = [
      ('Kamola R.', 'Ingliz o‘qituvchisi', 'Ariza', PillTone.neutral),
      ('Bekzod M.', 'Matematika o‘qituvchisi', 'Suhbat · 5-iyun', PillTone.warn),
      ('Sevara T.', 'Qabul administratori', 'Qabul qilindi', PillTone.success),
    ];
    return SfScaffold(
      colors: c,
      title: 'Xodimlar · HR',
      body: ListView(
        padding: _mPad,
        children: [
          Row(children: [
            Expanded(child: SfStatTile('Xodimlar', '${staff.length}', c.ink)),
            const SizedBox(width: 10),
            Expanded(child: SfStatTile('Nomzodlar', '${pipeline.length}', c.warn)),
            const SizedBox(width: 10),
            Expanded(child: SfStatTile('Suhbat', '1', c.primary)),
          ]),
          const SizedBox(height: 16),
          _eyebrow(context, 'Ishga olish jarayoni'),
          SfCard(
            child: Column(children: [
              for (int i = 0; i < pipeline.length; i++)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  decoration: BoxDecoration(
                      border: Border(bottom: i < pipeline.length - 1 ? BorderSide(color: c.border) : BorderSide.none)),
                  child: Row(children: [
                    SfAvatar(name: pipeline[i].$1, size: 34),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(pipeline[i].$1,
                            style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                        Text(pipeline[i].$2, style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                      ]),
                    ),
                    Pill(pipeline[i].$3, tone: pipeline[i].$4),
                  ]),
                ),
            ]),
          ),
          _eyebrow(context, 'Jamoa'),
          SfCard(
            child: Column(children: [
              for (int i = 0; i < staff.length; i++)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  decoration: BoxDecoration(
                      border: Border(bottom: i < staff.length - 1 ? BorderSide(color: c.border) : BorderSide.none)),
                  child: Row(children: [
                    SfAvatar(name: staff[i].$1, size: 34),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(staff[i].$1,
                            style: TextStyle(fontFamily: SfType.ui, fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
                        Text(staff[i].$2, style: TextStyle(fontFamily: SfType.ui, fontSize: 10.5, color: c.muted)),
                      ]),
                    ),
                    Text(staff[i].$3,
                        style: TextStyle(fontFamily: SfType.ui, fontSize: 10, color: c.muted2)),
                  ]),
                ),
            ]),
          ),
        ],
      ),
      bottomBar: _bottomBar(
        context,
        c,
        SfButton(
          icon: Icons.person_add_rounded,
          label: 'Yangi nomzod qo‘shish',
          primary: true,
          onTap: () => sfSnack(context, '👤 Yangi nomzod ariza (demo)'),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// 8. Rule book — role-filtered policy acknowledgment
// ════════════════════════════════════════════════════════════════════════
class RuleBookScreen extends StatefulWidget {
  final SfColors colors;
  const RuleBookScreen({super.key, required this.colors});
  @override
  State<RuleBookScreen> createState() => _RuleBookScreenState();
}

class _RuleBookScreenState extends State<RuleBookScreen> {
  bool accepted = false;
  static const _sections = [
    ('1. Umumiy qoidalar', 'Markaz hududida hurmat va xavfsizlik. Har bir xodim va o‘quvchi ushbu qoidalarga amal qiladi.'),
    ('2. Davomat', 'Darsga o‘z vaqtida kelish. Kechikish va yo‘qlik tizimda qayd etiladi.'),
    ('3. To‘lovlar', 'To‘lov muddati har oyning boshida. Kechiktirish so‘rovini ilova orqali yuborish mumkin.'),
    ('4. Xulq-atvor', 'Haqorat, bullying va nojo‘ya xatti-harakatlar taqiqlanadi (o‘zbek/rus/ingliz).'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    return SfScaffold(
      colors: c,
      title: 'Qoidalar kitobi',
      body: ListView(
        padding: _mPad,
        children: [
          Row(children: [
            Icon(Icons.menu_book_rounded, size: 18, color: c.primary),
            const SizedBox(width: 8),
            Text('Versiya 2.1 · rolingiz uchun',
                style: TextStyle(fontFamily: SfType.ui, fontSize: 12, fontWeight: FontWeight.w600, color: c.muted)),
          ]),
          const SizedBox(height: 12),
          for (final s in _sections)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: c.surface, border: Border.all(color: c.border), borderRadius: BorderRadius.circular(13)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.$1, style: TextStyle(fontFamily: SfType.ui, fontSize: 13.5, fontWeight: FontWeight.w800, color: c.ink)),
                const SizedBox(height: 6),
                Text(s.$2, style: TextStyle(fontFamily: SfType.ui, fontSize: 12, height: 1.4, color: c.ink2)),
              ]),
            ),
          if (accepted)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: c.successSoft, borderRadius: BorderRadius.circular(13)),
              child: Row(children: [
                Icon(Icons.verified_rounded, size: 20, color: c.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Qabul qilindi · audit jurnaliga yozildi',
                      style: TextStyle(fontFamily: SfType.ui, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.success)),
                ),
              ]),
            ),
        ],
      ),
      bottomBar: _bottomBar(
        context,
        c,
        SfButton(
          icon: accepted ? Icons.check_circle_rounded : null,
          label: accepted ? 'Qabul qilingan' : 'O‘qib chiqdim va qabul qilaman',
          primary: !accepted,
          onTap: () {
            if (accepted) return;
            setState(() => accepted = true);
            sfSnack(context, '✓ Qoidalar qabul qilindi', bg: const Color(0xFF4F7B3B));
          },
        ),
      ),
    );
  }
}
