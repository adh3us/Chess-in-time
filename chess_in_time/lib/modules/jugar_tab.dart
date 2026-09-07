import 'package:flutter/material.dart';
import '../chess_game_screen.dart';
import '../fischer_clock.dart';
import '../online_match_service.dart';
import '../supabase_config.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Módulo: Jugar (Estilo Clash Royale)
///
/// Pantalla principal de juego con:
/// - Tarjeta de Arena / Rango estilo Clash Royale (sube cada ~4 victorias).
/// - Botón central interactivo para encender/apagar matchmaking (reloj 5 min).
/// - Tabla de clasificación (Top 10 Global / Amigos).
/// - Acceso directo a modos de práctica offline (Jugar solo / Local).
/// ---------------------------------------------------------------------------
class JugarTab extends StatefulWidget {
  const JugarTab({super.key});

  @override
  State<JugarTab> createState() => _JugarTabState();
}

class _JugarTabState extends State<JugarTab> {
  bool _buscandoRival = false;
  int _tabRankIndex = 0; // 0 = Global, 1 = Amigos
  List<Map<String, dynamic>> _topJugadores = [];
  bool _cargandoRank = true;

  @override
  void initState() {
    super.initState();
    _cargarLeaderboard();
  }

  Future<void> _cargarLeaderboard() async {
    try {
      final response = await supabase
          .schema('chess_in_time')
          .from('ratings')
          .select('jugador, rating, partidas_jugadas')
          .eq('modalidad', 'rapida')
          .order('rating', ascending: false)
          .limit(10);

      if (mounted) {
        setState(() {
          _topJugadores = List<Map<String, dynamic>>.from(response as List);
          _cargandoRank = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _topJugadores = [];
          _cargandoRank = false;
        });
      }
    }
  }

  void _toggleMatchmaking() {
    final session = supabase.auth.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Iniciá sesión con tu cuenta de Gameros en la esquina superior derecha para jugar online clasificado.'),
          backgroundColor: Color(0xFFF59E0B),
        ),
      );
      return;
    }

    // Abre la sala de espera de ranked 5 min
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OnlineLobbyScreen(modality: ClockModality.rapida),
      ),
    );
  }

  /// Estructura de Arenas estilo Clash Royale basadas en ELO/Copas
  (String arenaNombre, int minElo, int maxElo, int icono) _calcularArena(int elo) {
    if (elo < 1250) return ('Arena 1: Iniciado', 1200, 1250, 1);
    if (elo < 1300) return ('Arena 2: Foso de Peones', 1250, 1300, 2);
    if (elo < 1350) return ('Arena 3: Fortaleza del Caballo', 1300, 1350, 3);
    if (elo < 1400) return ('Arena 4: Torre de Marfil', 1350, 1400, 4);
    if (elo < 1450) return ('Arena 5: Santuario del Alfil', 1400, 1450, 5);
    if (elo < 1500) return ('Arena 6: Palacio de la Reina', 1450, 1500, 6);
    return ('Arena Real: Gran Maestro', 1500, 2000, 7);
  }

  @override
  Widget build(BuildContext context) {
    final session = supabase.auth.currentSession;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarLeaderboard,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Tarjeta de Rango / Arena estilo Clash Royale
              _buildArenaCard(session),

              const SizedBox(height: 20),

              // 2. Botón Principal de Matchmaking 1v1 (5 min)
              _buildBattleButton(),

              const SizedBox(height: 16),

              // 3. Accesos rápidos offline
              _buildQuickOfflineActions(),

              const SizedBox(height: 24),

              // 4. Leaderboard Top 10 (Global / Amigos)
              _buildLeaderboardSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArenaCard(Session? session) {
    final elo = 1200; // ELO base inicial estándar
    final (nombreArena, minElo, maxElo, nivel) = _calcularArena(elo);
    final progreso = ((elo - minElo) / (maxElo - minElo)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$nivel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreArena,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Subís de nivel cada ~4 victorias • Partidas de 5 min',
                      style: TextStyle(
                        color: Colors.blueGrey.shade300,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        '$elo',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Copas / ELO',
                    style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 10,
              backgroundColor: const Color(0xFF334155),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$minElo', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11)),
              Text('Faltan ~4 victorias para la siguiente Arena',
                  style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w600)),
              Text('$maxElo', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBattleButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleMatchmaking,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.timer_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'BATALLA 1v1 (5 MIN)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'Matchmaking Rápido con reloj • Clasificatoria',
                      style: TextStyle(
                        color: Color(0xFFD1FAE5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickOfflineActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.blueGrey.shade700),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF1E293B).withOpacity(0.7),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SoloBoardScreen()),
              );
            },
            icon: const Icon(Icons.psychology_alt_rounded, size: 18, color: Color(0xFF38BDF8)),
            label: const Text('Jugar Solo', style: TextStyle(fontSize: 13)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.blueGrey.shade700),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              backgroundColor: const Color(0xFF1E293B).withOpacity(0.7),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ChessGameScreen()),
              );
            },
            icon: const Icon(Icons.people_alt_rounded, size: 18, color: Color(0xFFFBBF24)),
            label: const Text('Pass & Play', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.shade800),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.leaderboard_rounded, color: Color(0xFFFBBF24), size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Tabla de Clasificación',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Selector Global / Amigos
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    _buildRankTabButton('Global', 0),
                    _buildRankTabButton('Amigos', 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_tabRankIndex == 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'El ranking de amigos se habilitará cuando\nse sincronice con el sistema de amigos de Gameros.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey.shade300, fontSize: 13),
                ),
              ),
            )
          else if (_cargandoRank)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_topJugadores.isEmpty)
            _buildSampleLeaderboard()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _topJugadores.length,
              separatorBuilder: (_, __) => Divider(color: Colors.blueGrey.shade800, height: 1),
              itemBuilder: (context, index) {
                final row = _topJugadores[index];
                final rating = row['rating'] ?? 1200;
                final jugadorId = row['jugador']?.toString() ?? 'Jugador';
                final displayId = jugadorId.length > 8 ? '${jugadorId.substring(0, 8)}...' : jugadorId;
                return _buildLeaderboardRow(index + 1, displayId, rating);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRankTabButton(String label, int index) {
    final active = _tabRankIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabRankIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF38BDF8) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black87 : Colors.blueGrey.shade300,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSampleLeaderboard() {
    final muestras = [
      ('1', 'ReyTorus', 1640),
      ('2', 'GamerosMaster', 1590),
      ('3', 'PeonAlPaso', 1510),
      ('4', 'CaballoDeHierro', 1480),
      ('5', 'AlfilTigre', 1420),
      ('6', 'TorreBlanca', 1390),
      ('7', 'LucasG', 1350),
      ('8', 'EnroqueCorto', 1310),
      ('9', 'JaqueMate01', 1280),
      ('10', 'Ajedrecista_AR', 1250),
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: muestras.length,
      separatorBuilder: (_, __) => Divider(color: Colors.blueGrey.shade800, height: 1),
      itemBuilder: (context, index) {
        final (pos, nombre, copas) = muestras[index];
        return _buildLeaderboardRow(int.parse(pos), nombre, copas);
      },
    );
  }

  Widget _buildLeaderboardRow(int pos, String nombre, int copas) {
    Color? posColor;
    Widget? icon;
    if (pos == 1) {
      posColor = const Color(0xFFFBBF24);
      icon = const Icon(Icons.workspace_premium, color: Color(0xFFFBBF24), size: 20);
    } else if (pos == 2) {
      posColor = const Color(0xFFE2E8F0);
      icon = const Icon(Icons.workspace_premium, color: Color(0xFFCBD5E1), size: 20);
    } else if (pos == 3) {
      posColor = const Color(0xFFB45309);
      icon = const Icon(Icons.workspace_premium, color: Color(0xFFB45309), size: 20);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Center(
              child: icon ??
                  Text(
                    '$pos',
                    style: TextStyle(
                      color: Colors.blueGrey.shade400,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF334155),
            child: Text(
              nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?',
              style: TextStyle(color: posColor ?? Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              nombre,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFFBBF24), size: 16),
              const SizedBox(width: 4),
              Text(
                '$copas',
                style: const TextStyle(
                  color: Color(0xFFFBBF24),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
