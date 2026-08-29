import 'package:supabase_flutter/supabase_flutter.dart';

/// ---------------------------------------------------------------------------
/// CHESS IN TIME — Conexión a Supabase (Fase 5)
///
/// Mismo proyecto Supabase que usa Gameros (login compartido vía
/// auth.users), pero Chess in Time vive en su propio esquema de Postgres
/// (`chess_in_time`), separado de `public`. Acá solo se usa la anon key —
/// nunca la service_role — porque la seguridad real la da el RLS
/// (Row Level Security) configurado en cada tabla, no la clave en sí.
/// La anon key está pensada para vivir en el cliente, no es un secreto
/// como la service_role.
/// ---------------------------------------------------------------------------

const String supabaseUrl = 'https://bgwvtfgwhpinfotzyucn.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJnd3Z0Zmd3aHBpbmZvdHp5dWNuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY3OTgyMTAsImV4cCI6MjEwMjM3NDIxMH0.P1j452eng44SBVn6uAJpWvkrqcEV3WNPIGATa6VhZAk';

Future<void> initSupabase() async {
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
}

SupabaseClient get supabase => Supabase.instance.client;
