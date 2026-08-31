import 'package:flutter/material.dart';

import 'testu_i18n.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// Dashboard tab — "Your readiness". Mastery as labels, never bare numbers;
/// every signal explainable. No white CTA here: the dashboard reports, the
/// other screens act.
class TestuDashboardScreen extends StatelessWidget {
  const TestuDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
        children: [
          Text(
            L('Your readiness', 'Tu preparación'),
            style: TextStyle(
              fontFamily: 'Sora',
              fontWeight: FontWeight.w700,
              fontSize: 21,
              letterSpacing: -0.21,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 12),
          const _ReadinessCard(),
          const SizedBox(height: 12),
          const _PeerCard(),
          const SizedBox(height: 12),
          const _CalibrationCard(),
          const SizedBox(height: 12),
          const _WeekCard(),
          const SizedBox(height: 12),
          _MastRowsCard(
            title: L('MASTERY BY TOPIC', 'DOMINIO POR TEMA'),
            rows: [
              _MastRow(L('FOD Prevention', 'Prevención de FOD'),
                  L('Improve Mode available', 'Modo Mejorar disponible'),
                  TestuPill(L('Expert · Stable', 'Experto · Estable'),
                      color: t.greenText,
                      borderColor: const Color(0xFF2F6A4C))),
              _MastRow(
                  L('Ramp Safety & Turnaround', 'Seguridad en Rampa y Turnaround'),
                  L('Learn Mode · 21 of 36', 'Modo Aprender · 21 de 36'),
                  TestuPill(
                      L('Competent · Review soon', 'Competente · Repasar pronto'),
                      color: t.gold, borderColor: const Color(0xFF8A7A3A))),
              _MastRow(L('Radio Communication', 'Comunicación por Radio'),
                  L('Sully recommends 10 min today', 'Sully recomienda 10 min hoy'),
                  TestuPill(L('Competent · At risk', 'Competente · En riesgo'),
                      color: t.amber, borderColor: const Color(0xFF7A5C1E))),
            ],
          ),
          const SizedBox(height: 12),
          _MastRowsCard(
            title: L('ROLE COMPETENCIES · EVIDENCE FROM YOUR ANSWERS',
                'COMPETENCIAS DEL ROL · EVIDENCIA DE TUS RESPUESTAS'),
            rows: [
              _MastRow(
                  L('Safe aircraft handling', 'Manejo seguro de la aeronave'),
                  L('3 of 4 behaviors evidenced', '3 de 4 conductas evidenciadas'),
                  TestuPill(L('Strong', 'Sólido'),
                      color: t.greenText,
                      borderColor: const Color(0xFF2F6A4C))),
              _MastRow(
                  L('Situational awareness on stand',
                      'Conciencia situacional en el stand'),
                  L('1 of 3 behaviors evidenced', '1 de 3 conductas evidenciadas'),
                  TestuPill(L('Building', 'En desarrollo'),
                      color: t.amber, borderColor: const Color(0xFF7A5C1E))),
              _MastRow(
                  L('Communication & coordination', 'Comunicación y coordinación'),
                  L('1 of 5 behaviors evidenced · tied to Radio Communication',
                      '1 de 5 conductas evidenciadas · ligado a Comunicación por Radio'),
                  TestuPill(L('At risk', 'En riesgo'),
                      color: const Color(0xFFD08B8B),
                      borderColor: const Color(0xFF6E3535))),
            ],
            note: L(
                'Behaviors are what Vueling expects from your role. Every benchmark answer records evidence toward them.',
                'Las conductas son lo que Vueling espera de tu rol. Cada respuesta de referencia registra evidencia hacia ellas.'),
          ),
          const SizedBox(height: 12),
          const _CertCard(),
        ],
      ),
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  const _ReadinessCard();

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TestuEyebrow.h4(
              L('ROLE READINESS · RAMP AGENT, SAFETY LEAD',
                  'PREPARACIÓN DEL ROL · AGENTE DE RAMPA')),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  L('Ready · Monitor', 'Preparada · Vigilar'),
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Color(0xFFE9E8E4),
                  ),
                ),
              ),
              TestuEyebrow(L('EXPLAINABLE', 'EXPLICABLE')),
            ],
          ),
          const SizedBox(height: 12),
          _CompLine(L('Mastery vs required levels', 'Dominio vs niveles requeridos'),
              L('On track', 'En buen camino'), t.greenText),
          _CompLine(L('Retention', 'Retención'),
              L('1 topic at risk', '1 tema en riesgo'), t.amber),
          _CompLine(L('Certificates', 'Certificados'),
              L('Renewal in 12 days', 'Renovación en 12 días'), t.amber,
              last: true),
        ],
      ),
    );
  }
}

class _CompLine extends StatelessWidget {
  const _CompLine(this.label, this.value, this.valueColor, {this.last = false});

  final String label;
  final String value;
  final Color valueColor;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF17171A)))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Geist',
                fontSize: 12,
                color: Color(0xFFC2C1BD),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Geist',
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeerCard extends StatelessWidget {
  const _PeerCard();

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: TestuEyebrow.h4(L(
                      'PEER COMPARISON · RAMP AGENTS, BCN',
                      'COMPARACIÓN CON COMPAÑEROS · AGENTES DE RAMPA, BCN'))),
              const _PeerStack(),
              const SizedBox(width: 8),
              Text(
                L('38 peers', '38 compañeros'),
                style: TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: 9.5,
                  color: t.faint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PeerMetric(L('Confidence calibration', 'Calibración de confianza'),
              L('82% · you', '82% · tú'), 0.82, 0.74),
          const SizedBox(height: 14),
          _PeerMetric(L('Required topics at level', 'Temas obligatorios al nivel'),
              L('86% · you', '86% · tú'), 0.86, 0.71),
          const SizedBox(height: 14),
          _PeerMetric(L('Training days this week', 'Días de práctica esta semana'),
              L('5 of 7 · you', '5 de 7 · tú'), 0.71, 0.43),
          const SizedBox(height: 12),
          Row(
            children: [
              _LegendDot(t.orange, L('You', 'Tú')),
              const SizedBox(width: 14),
              _LegendDot(t.mut, L('Peer median', 'Mediana del grupo')),
              const Spacer(),
              TestuPill(L('Top quartile · calibration', 'Cuartil superior · calibración'),
                  color: t.greenText, borderColor: const Color(0xFF2F6A4C)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            L('Anonymised comparison with ramp agents at your base. Your peers never see your individual results.',
                'Comparación anónima con agentes de rampa de tu base. Tus compañeros nunca ven tus resultados individuales.'),
            style: kNote,
          ),
        ],
      ),
    );
  }
}

/// Overlapping 22px peer avatars with card-colored rims.
class _PeerStack extends StatelessWidget {
  const _PeerStack();

  static const _imgs = [
    'assets/img/p_jordi.jpg',
    'assets/img/p_laia.jpg',
    'assets/img/p_karsten.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return SizedBox(
      width: 22.0 + 2 * 15, // three avatars, -7px overlap
      height: 22,
      child: Stack(
        children: [
          for (var i = 0; i < _imgs.length; i++)
            Positioned(
              left: i * 15,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: t.card, width: 2),
                ),
                child:
                    ClipOval(child: Image.asset(_imgs[i], fit: BoxFit.cover)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PeerMetric extends StatelessWidget {
  const _PeerMetric(this.label, this.you, this.youFrac, this.medFrac);

  final String label;
  final String you;
  final double youFrac;
  final double medFrac;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 11.5,
                  color: Color(0xFFC2C1BD),
                ),
              ),
            ),
            Text(
              you,
              style: const TextStyle(
                fontFamily: 'Geist',
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                color: Color(0xFFE6E4E0),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SizedBox(
          height: 6,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF26262C),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  width: box.maxWidth * youFrac,
                  decoration: BoxDecoration(
                    color: t.orange,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Positioned(
                  left: box.maxWidth * medFrac - 1,
                  top: -3,
                  bottom: -3,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: t.mut,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot(this.color, this.label);

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: kCaption,
        ),
      ],
    );
  }
}

class _CalibrationCard extends StatelessWidget {
  const _CalibrationCard();

  @override
  Widget build(BuildContext context) {
    return TestuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TestuEyebrow.h4(L('CONFIDENCE CALIBRATION · 82%',
              'CALIBRACIÓN DE CONFIANZA · 82%')),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _Quad('14',
                      L('Consolidated\ncorrect · certain',
                          'Consolidado\ncorrecto · seguro'))),
              const SizedBox(width: 8),
              Expanded(
                  child: _Quad('4',
                      L('Fragile\ncorrect · unsure',
                          'Frágil\ncorrecto · inseguro'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                  child: _Quad('3',
                      L('Known gaps\nincorrect · unsure',
                          'Lagunas conocidas\nincorrecto · inseguro'))),
              const SizedBox(width: 8),
              Expanded(
                  child: _Quad('1',
                      L('Misconception\nincorrect · certain',
                          'Concepto erróneo\nincorrecto · seguro'),
                      hot: true)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Quad extends StatelessWidget {
  const _Quad(this.count, this.label, {this.hot = false});

  final String count;
  final String label;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        border: Border.all(color: hot ? const Color(0xFF6E3535) : t.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: TextStyle(
              fontFamily: 'GeistMono',
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: hot ? const Color(0xFFD08B8B) : t.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 10,
              height: 1.35,
              color: t.mut,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard();

  // (day, correct px, incorrect px) — heights from the prototype.
  static List<(String, double, double)> get _days => [
    (L('MON', 'LUN'), 48.0, 28.0),
    (L('TUE', 'MAR'), 38.0, 16.0),
    (L('WED', 'MIÉ'), 62.0, 32.0),
    (L('THU', 'JUE'), 22.0, 14.0),
    (L('FRI', 'VIE'), 32.0, 18.0),
    (L('SAT', 'SÁB'), 26.0, 8.0),
    (L('SUN', 'DOM'), 46.0, 34.0),
  ];

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TestuEyebrow.h4(
              L('LAST 7 DAYS · CORRECT VS INCORRECT',
                  'ÚLTIMOS 7 DÍAS · CORRECTAS VS INCORRECTAS')),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (day, c, i) in _days)
                Column(
                  children: [
                    SizedBox(
                      height: 68,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _Bar(c, const Color(0xFF3F7D5F)),
                          const SizedBox(width: 3),
                          _Bar(i, const Color(0xFF8F4444)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      day,
                      style: TextStyle(
                        fontFamily: 'GeistMono',
                        fontWeight: FontWeight.w500,
                        fontSize: 8,
                        color: t.faint,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar(this.height, this.color);

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 7,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}

class _MastRow {
  const _MastRow(this.title, this.sub, this.pill);

  final String title;
  final String sub;
  final Widget pill;
}

class _MastRowsCard extends StatelessWidget {
  const _MastRowsCard({required this.title, required this.rows, this.note});

  final String title;
  final List<_MastRow> rows;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return TestuCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TestuEyebrow.h4(title),
          const SizedBox(height: 4),
          for (final r in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: r == rows.last
                  ? null
                  : const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Color(0xFF17171A)))),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          style: const TextStyle(
                            fontFamily: 'Geist',
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                            color: Color(0xFFE9E8E4),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.sub,
                          style: kMeta,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  r.pill,
                ],
              ),
            ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note!,
              style: kNote,
            ),
          ],
        ],
      ),
    );
  }
}

class _CertCard extends StatelessWidget {
  const _CertCard();

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF8A7A3A)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '✓',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 17,
                color: t.gold,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L('Ramp Safety — Certified', 'Seguridad en Rampa — Certificada'),
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Color(0xFFE9E8E4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Valid · renewal evaluation due Sep 10',
                  style: kLabel,
                ),
              ],
            ),
          ),
          Text(
            L('ISSUED BY VUELING\nVERIFIED BY TESTU',
                'EMITIDO POR VUELING\nVERIFICADO POR TESTU'),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 8,
              height: 1.6,
              letterSpacing: 0.64, // +0.08em
              color: t.faint,
            ),
          ),
        ],
      ),
    );
  }
}
