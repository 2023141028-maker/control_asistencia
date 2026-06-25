import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart'; // <--- IMPORTACIÓN AGREGADA

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Variable para activar/desactivar el modo fuera de oficina
  bool _isRemoteMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Control de Asistencia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              "¡Bienvenido!",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // INTERRUPTOR DE MODO FUERA DE OFICINA
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: _isRemoteMode ? Colors.orange.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isRemoteMode ? Colors.orange : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Modo Fuera de Oficina",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isRemoteMode ? Colors.orange : Colors.black,
                        ),
                      ),
                      Text(
                        _isRemoteMode
                            ? "Activado: Sin validación GPS"
                            : "Desactivado: Validación GPS activa",
                        style: TextStyle(
                          fontSize: 12,
                          color: _isRemoteMode ? Colors.orange : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: _isRemoteMode,
                    activeColor: Colors.orange,
                    onChanged: (bool value) {
                      setState(() {
                        _isRemoteMode = value;
                      });
                      // Mostramos un mensaje confirmando el cambio
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value
                              ? '🔓 Modo fuera de oficina activado (GPS desactivado)'
                              : '🔒 Modo oficina activado (GPS activado)'
                          ),
                          backgroundColor: value ? Colors.orange : Colors.blue,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Botón ENTRADA
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegisterScreen(
                        tipo: 'entrada',
                        isRemoteMode: _isRemoteMode, // Pasamos el estado del interruptor
                      ),
                    ),
                  );
                },
                child: const Text(
                  '📸 Registrar Entrada',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Botón SALIDA
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegisterScreen(
                        tipo: 'salida',
                        isRemoteMode: _isRemoteMode, // Pasamos el estado del interruptor
                      ),
                    ),
                  );
                },
                child: const Text(
                  '🚪 Registrar Salida',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Botón HISTORIAL
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HistoryScreen()),
                  );
                },
                child: const Text(
                  '📋 Ver Historial',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // <--- BOTÓN DE MI PERFIL AGREGADO AQUÍ --->
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade100,
                  foregroundColor: Colors.purple.shade900,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
                child: const Text(
                  '👤 Mi Perfil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // <--- FIN DEL BOTÓN AGREGADO --->

          ],
        ),
      ),
    );
  }
}