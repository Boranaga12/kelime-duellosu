import 'package:flutter/material.dart';

class RoomPlayer {
  final String id;
  final String name;
  final String avatarEmoji;
  final String? avatarUrl;
  final String tag;
  final int level;
  final int trophies;
  final String teamId;
  final bool isHost;
  final bool isBot;
  final int? colorValue;

  const RoomPlayer({
    required this.id,
    required this.name,
    required this.avatarEmoji,
    this.avatarUrl,
    this.tag = '#KW-0000',
    this.level = 1,
    this.trophies = 1200,
    this.teamId = 'team_1',
    this.isHost = false,
    this.isBot = false,
    this.colorValue,
  });

  Color get effectiveColor => colorValue != null
      ? Color(colorValue!)
      : const Color(0xFF10B981);

  RoomPlayer copyWith({
    String? id,
    String? name,
    String? avatarEmoji,
    String? avatarUrl,
    String? tag,
    int? level,
    int? trophies,
    String? teamId,
    bool? isHost,
    bool? isBot,
    int? colorValue,
  }) {
    return RoomPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      tag: tag ?? this.tag,
      level: level ?? this.level,
      trophies: trophies ?? this.trophies,
      teamId: teamId ?? this.teamId,
      isHost: isHost ?? this.isHost,
      isBot: isBot ?? this.isBot,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatarEmoji,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'tag': tag,
        'level': level,
        'trophies': trophies,
        'team_id': teamId,
        'is_host': isHost,
        'is_bot': isBot,
        if (colorValue != null) 'color_value': colorValue,
      };

  factory RoomPlayer.fromJson(Map<String, dynamic> json) => RoomPlayer(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Oyuncu',
        avatarEmoji: json['avatar']?.toString() ?? '👑',
        avatarUrl: json['avatar_url']?.toString(),
        tag: json['tag']?.toString() ?? '#KW-0000',
        level: (json['level'] as num?)?.toInt() ?? 1,
        trophies: (json['trophies'] as num?)?.toInt() ?? 1200,
        teamId: json['team_id']?.toString() ?? 'team_1',
        isHost: json['is_host'] == true,
        isBot: json['is_bot'] == true,
        colorValue: (json['color_value'] as num?)?.toInt(),
      );
}

class TeamConfig {
  final String id;
  final String name;
  final Color color;

  const TeamConfig({
    required this.id,
    required this.name,
    required this.color,
  });

  TeamConfig copyWith({
    String? id,
    String? name,
    Color? color,
  }) {
    return TeamConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.toARGB32(),
      };

  factory TeamConfig.fromJson(Map<String, dynamic> json) => TeamConfig(
        id: json['id']?.toString() ?? 'team_1',
        name: json['name']?.toString() ?? 'Takım',
        color: Color((json['color'] as num?)?.toInt() ?? 0xFFEF4444),
      );
}

class CustomRoom {
  final String id;
  final String roomCode;
  final String roomName;
  final String hostId;
  final String hostName;
  final bool isLocked;
  final String? password;
  final int maxPlayers; // 2, 3, 4, 5, 6
  final bool isTeamMode;
  final int teamCount; // 2 veya 3
  final List<TeamConfig> teams;
  final int targetWins; // 2, 3, 5
  final List<RoomPlayer> players;
  final String status; // 'waiting', 'in_progress', 'finished'

  const CustomRoom({
    required this.id,
    required this.roomCode,
    required this.roomName,
    required this.hostId,
    required this.hostName,
    this.isLocked = false,
    this.password,
    this.maxPlayers = 4,
    this.isTeamMode = true,
    this.teamCount = 2,
    this.teams = const [
      TeamConfig(id: 'team_1', name: 'Kırmızı Takım', color: Color(0xFFEF4444)),
      TeamConfig(id: 'team_2', name: 'Mavi Takım', color: Color(0xFF0284C7)),
    ],
    this.targetWins = 2,
    this.players = const [],
    this.status = 'waiting',
  });

  CustomRoom copyWith({
    String? id,
    String? roomCode,
    String? roomName,
    String? hostId,
    String? hostName,
    bool? isLocked,
    String? password,
    int? maxPlayers,
    bool? isTeamMode,
    int? teamCount,
    List<TeamConfig>? teams,
    int? targetWins,
    List<RoomPlayer>? players,
    String? status,
  }) {
    return CustomRoom(
      id: id ?? this.id,
      roomCode: roomCode ?? this.roomCode,
      roomName: roomName ?? this.roomName,
      hostId: hostId ?? this.hostId,
      hostName: hostName ?? this.hostName,
      isLocked: isLocked ?? this.isLocked,
      password: password ?? this.password,
      maxPlayers: maxPlayers ?? this.maxPlayers,
      isTeamMode: isTeamMode ?? this.isTeamMode,
      teamCount: teamCount ?? this.teamCount,
      teams: teams ?? this.teams,
      targetWins: targetWins ?? this.targetWins,
      players: players ?? this.players,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_code': roomCode,
        'room_name': roomName,
        'host_id': hostId,
        'host_name': hostName,
        'is_locked': isLocked,
        'password': password,
        'max_players': maxPlayers,
        'is_team_mode': isTeamMode,
        'team_count': teamCount,
        'teams': teams.map((t) => t.toJson()).toList(),
        'target_wins': targetWins,
        'players': players.map((p) => p.toJson()).toList(),
        'status': status,
      };

  factory CustomRoom.fromJson(Map<String, dynamic> json) => CustomRoom(
        id: json['id']?.toString() ?? '',
        roomCode: json['room_code']?.toString() ?? '',
        roomName: json['room_name']?.toString() ?? 'Özel Oda',
        hostId: json['host_id']?.toString() ?? '',
        hostName: json['host_name']?.toString() ?? '',
        isLocked: json['is_locked'] == true,
        password: json['password']?.toString(),
        maxPlayers: (json['max_players'] as num?)?.toInt() ?? 4,
        isTeamMode: json['is_team_mode'] == true,
        teamCount: (json['team_count'] as num?)?.toInt() ?? 2,
        teams: (json['teams'] as List?)
                ?.map((t) => TeamConfig.fromJson(Map<String, dynamic>.from(t as Map)))
                .toList() ??
            const [
              TeamConfig(id: 'team_1', name: 'Kırmızı Takım', color: Color(0xFFEF4444)),
              TeamConfig(id: 'team_2', name: 'Mavi Takım', color: Color(0xFF0284C7)),
            ],
        targetWins: (json['target_wins'] as num?)?.toInt() ?? 2,
        players: (json['players'] as List?)
                ?.map((p) => RoomPlayer.fromJson(Map<String, dynamic>.from(p as Map)))
                .toList() ??
            const [],
        status: json['status']?.toString() ?? 'waiting',
      );
}
