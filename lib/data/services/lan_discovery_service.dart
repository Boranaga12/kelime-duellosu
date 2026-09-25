import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/custom_room.dart';

/// Aynı Wi-Fi ağı veya mobil ortak erişim noktası (Hotspot) üzerindeki
/// cihazların birbirlerinin özel odalarını anında keşfetmesini sağlayan P2P Yerel Ağ Servisi.
class LanDiscoveryService {
  static const int _broadcastPort = 45455;
  static RawDatagramSocket? _broadcastSocket;
  static RawDatagramSocket? _listenSocket;
  static Timer? _broadcastTimer;
  static CustomRoom? _broadcastingRoom;

  /// 1. Host: Odayı yerel ağdaki herkese periyodik olarak yayınlar
  static Future<void> startBroadcasting(CustomRoom room) async {
    _broadcastingRoom = room;
    if (_broadcastTimer != null && _broadcastSocket != null) return;

    try {
      _broadcastSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _broadcastSocket!.broadcastEnabled = true;

      _broadcastTimer?.cancel();
      _broadcastTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
        if (_broadcastSocket == null || _broadcastingRoom == null) return;
        try {
          final payload = jsonEncode({
            'protocol': 'kelime_duellosu_lan_v1',
            'room': _broadcastingRoom!.toJson(),
          });
          final bytes = utf8.encode(payload);
          _broadcastSocket!.send(bytes, InternetAddress('255.255.255.255'), _broadcastPort);
        } catch (_) {}
      });
      debugPrint('📡 [LAN] Yerel ağ oda yayını başlatıldı (Port: $_broadcastPort)');
    } catch (e) {
      debugPrint('LAN broadcast başlatma hatası: $e');
    }
  }

  /// Yayınlanan oda bilgilerini günceller
  static void updateBroadcastingRoom(CustomRoom room) {
    _broadcastingRoom = room;
  }

  /// 2. Host: Odayı yayından kaldırır
  static void stopBroadcasting() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
    _broadcastingRoom = null;
    try {
      _broadcastSocket?.close();
    } catch (_) {}
    _broadcastSocket = null;
  }

  /// 3. Misafir: Yerel ağdaki açık odaları dinler
  static Future<void> startListening({
    required void Function(CustomRoom room) onRoomDiscovered,
  }) async {
    if (_listenSocket != null) return;

    try {
      _listenSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _broadcastPort,
        reuseAddress: true,
      );

      _listenSocket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _listenSocket?.receive();
          if (datagram != null) {
            try {
              final text = utf8.decode(datagram.data);
              final map = jsonDecode(text) as Map<String, dynamic>;
              if (map['protocol'] == 'kelime_duellosu_lan_v1' && map['room'] != null) {
                final room = CustomRoom.fromJson(Map<String, dynamic>.from(map['room']));
                onRoomDiscovered(room);
              }
            } catch (_) {}
          }
        }
      });
      debugPrint('🎧 [LAN] Yerel ağ dinleme aktif.');
    } catch (e) {
      debugPrint('LAN dinleme başlatma hatası: $e');
    }
  }

  /// 4. Dinlemeyi durdurur
  static void stopListening() {
    try {
      _listenSocket?.close();
    } catch (_) {}
    _listenSocket = null;
  }
}
