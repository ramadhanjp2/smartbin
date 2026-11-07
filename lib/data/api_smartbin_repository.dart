import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
import 'smartbin_repository.dart';

const defaultSmartbinApiUrl = 'https://api-smartbin.ramadhanjp.my.id/api/v1';

class ApiSmartbinRepository implements SmartbinRepository {
  ApiSmartbinRepository({required String baseUrl, required this.client, required this.secureStorage})
    : _baseUri = Uri.parse(_normalizeBaseUrl(baseUrl)) {
    if (!_baseUri.hasAuthority || !(_baseUri.scheme == 'https' || _baseUri.scheme == 'http')) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Must be an absolute HTTP(S) URL.');
    }
  }

  static const _accessTokenKey = 'smartbin_access_token';
  static const _refreshTokenKey = 'smartbin_refresh_token';
  static const _timeout = Duration(seconds: 20);

  final Uri _baseUri;
  final http.Client client;
  final FlutterSecureStorage secureStorage;
  Future<void>? _refreshing;

  static String _normalizeBaseUrl(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    return '$normalized/';
  }

  @override
  Future<AppUser?> restoreSession() async {
    final refreshToken = await secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) return null;
    try {
      final data = _asMap(await _request('GET', 'me'));
      return _userFromJson(data);
    } on AppException catch (error) {
      if (error.field == 'unauthorized') {
        await _clearTokens();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AppUser> login({required String identifier, required String password, required bool asAdmin}) async {
    final response = _asMap(await _request('POST', 'auth/login', body: {'identifier': identifier, 'password': password}, authenticated: false));
    await _saveTokens(response);
    final user = _userFromJson(_asMap(response['user']));
    return user;
  }

  @override
  Future<AppUser> register({required String nik, required String name, required String email, required String password}) async {
    final response = _asMap(
      await _request('POST', 'auth/register', body: {'nik': nik, 'name': name, 'email': email, 'password': password}, authenticated: false),
    );
    await _saveTokens(response);
    return _userFromJson(_asMap(response['user']));
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await secureStorage.read(key: _refreshTokenKey);
      if (refreshToken != null) {
        await _request('POST', 'auth/logout', body: {'refreshToken': refreshToken});
      }
    } finally {
      await _clearTokens();
    }
  }

  @override
  Future<AppUser> me() async => _userFromJson(_asMap(await _request('GET', 'me')));

  @override
  Future<AppUser> updateName(String name) async {
    final response = _asMap(await _request('PATCH', 'me', body: {'name': name}));
    return _userFromJson(response);
  }

  @override
  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    await _request('PATCH', 'me', body: {'oldPassword': oldPassword, 'newPassword': newPassword});
  }

  @override
  Future<LinkResult> linkCard(String uid) async {
    final response = _asMap(await _request('POST', 'cards/link', body: {'uid': uid}));
    return LinkResult(creditedPoints: _intValue(response['creditedPoints']), creditedDeposits: _intValue(response['creditedDeposits']));
  }

  @override
  Future<void> unlinkCard(String password) async {
    await _request('DELETE', 'cards/me', body: {'password': password});
  }

  @override
  Future<PointsSummary> pointsSummary() async {
    final json = _asMap(await _request('GET', 'points/summary'));
    return PointsSummary(
      balance: _intValue(json['balance']),
      heldPoints: _intValue(json['heldPoints']),
      heldDeposits: _intValue(json['heldDeposits']),
      month: _dateValue(json['month']),
      organicG: _intValue(json['organicG']),
      inorganicG: _intValue(json['inorganicG']),
      organicCount: _intValue(json['organicCount']),
      inorganicCount: _intValue(json['inorganicCount']),
      organicPoints: _intValue(json['organicPoints']),
      inorganicPoints: _intValue(json['inorganicPoints']),
      residuG: _intValue(json['residuG'], fallback: 0),
      residuCount: _intValue(json['residuCount'], fallback: 0),
      updatedAt: _dateValue(json['updatedAt']),
    );
  }

  @override
  Future<List<Deposit>> deposits({WasteType? type}) async {
    final all = <Deposit>[];
    String? cursor;
    do {
      final query = <String, String>{'limit': '100'};
      if (type != null) query['type'] = type.name.toUpperCase();
      if (cursor != null) query['cursor'] = cursor;
      final response = _asMap(await _request('GET', 'deposits', query: query));
      final rows = _asList(response['data']);
      all.addAll(rows.map((row) => _depositFromJson(_asMap(row))));
      cursor = _optionalString(response['nextCursor']);
    } while (cursor != null);
    return all;
  }

  @override
  Future<List<Deposit>> recentDeposits({int limit = 3}) async {
    final response = _asMap(await _request('GET', 'deposits', query: {'limit': '$limit'}));
    return _asList(response['data']).map((row) => _depositFromJson(_asMap(row))).toList();
  }

  @override
  Future<DepositPage> depositsPage({WasteType? type, DateTime? from, DateTime? to, String? cursor, int limit = 20}) async {
    final query = <String, String>{'limit': '$limit'};
    if (type != null) query['type'] = type.name.toUpperCase();
    if (from != null) query['from'] = from.toUtc().toIso8601String();
    if (to != null) query['to'] = to.toUtc().toIso8601String();
    if (cursor != null) query['cursor'] = cursor;
    final response = _asMap(await _request('GET', 'deposits', query: query));
    return DepositPage(
      items: _asList(response['data']).map((row) => _depositFromJson(_asMap(row))).toList(),
      nextCursor: _optionalString(response['nextCursor']),
    );
  }

  @override
  Future<DepositStats> depositStats({DateTime? from, DateTime? to}) async {
    final query = <String, String>{};
    if (from != null) query['from'] = from.toUtc().toIso8601String();
    if (to != null) query['to'] = to.toUtc().toIso8601String();
    final json = _asMap(await _request('GET', 'deposits/stats', query: query.isEmpty ? null : query));
    DepositTypeStats part(String key) {
      final row = _asMap(json[key] ?? const <String, Object?>{});
      return DepositTypeStats(
        count: _intValue(row['count'], fallback: 0),
        weightG: _intValue(row['weightG'], fallback: 0),
        points: _intValue(row['points'], fallback: 0),
      );
    }

    return DepositStats(organik: part('organik'), anorganik: part('anorganik'), residu: part('residu'));
  }

  @override
  Future<Deposit> deposit(String transactionId) async {
    final result = await _request('GET', 'deposits/${Uri.encodeComponent(transactionId)}');
    return _depositFromJson(_asMap(result));
  }

  @override
  Future<Uint8List?> capturePhoto(String transactionId) async {
    final uri = _baseUri.resolve('captures/${Uri.encodeComponent(transactionId)}');
    try {
      var response = await _send('GET', uri, authenticated: true);
      if (response.statusCode == 401) {
        await _refreshAccessToken();
        response = await _send('GET', uri, authenticated: true);
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppException('Foto setoran gagal dimuat (HTTP ${response.statusCode}).');
      }
      return response.bodyBytes;
    } on http.ClientException {
      throw const AppException('Tidak dapat memuat foto setoran. Periksa koneksi internet Anda.');
    } on TimeoutException {
      throw const AppException('Server terlalu lama merespons saat memuat foto setoran.');
    }
  }

  @override
  Future<Rates> rates() async => _ratesFromJson(_asMap(await _request('GET', 'rates')));

  @override
  Future<List<Machine>> machines() async {
    final rows = _asList(await _request('GET', 'machines'));
    return rows.map((row) {
      final json = _asMap(row);
      final status = _enumValue(MachineStatus.values, _stringValue(json['status']).toLowerCase(), (value) => value.name, 'machine status');
      return Machine(
        id: _stringValue(json['id']),
        deviceId: _stringValue(json['deviceId'], fallback: _stringValue(json['code'], fallback: _stringValue(json['id']))),
        name: _stringValue(json['name']),
        campus: _stringValue(json['campus'], fallback: ''),
        location: _stringValue(json['location'], fallback: ''),
        status: status,
        lastSeen: json['lastSeen'] == null ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) : _dateValue(json['lastSeen']),
        organicFill: _intValue(json['organicFill']),
        inorganicFill: _intValue(json['inorganicFill']),
        residuFill: _intValue(json['residuFill'], fallback: 0),
        organicCmLeft: _intValue(json['organicCmLeft'], fallback: 0),
        inorganicCmLeft: _intValue(json['inorganicCmLeft'], fallback: 0),
        residuCmLeft: _intValue(json['residuCmLeft'], fallback: 0),
        temperatureC: 0,
        modules: const [],
      );
    }).toList();
  }

  @override
  Future<List<TelemetryLog>> telemetry(String machineId) async {
    final rows = _asList(await _request('GET', 'machines/${Uri.encodeComponent(machineId)}/telemetry', query: const {'limit': '20'}));
    return rows.map((row) {
      final json = _asMap(row);
      final payload = _asMap(json['payload'] ?? const <String, Object?>{});
      final kind = _stringValue(json['kind'], fallback: 'event');
      return TelemetryLog(
        title: kind[0].toUpperCase() + kind.substring(1),
        detail: jsonEncode(payload),
        time: _dateValue(json['receivedAt']),
        kind: kind,
      );
    }).toList();
  }

  @override
  Stream<void> machineStatusEvents() {
    late final StreamController<void> controller;
    StreamSubscription<String>? subscription;
    var closed = false;

    Future<void> connect() async {
      var delay = const Duration(seconds: 2);
      while (!closed) {
        try {
          final accessToken = await secureStorage.read(key: _accessTokenKey);
          if (accessToken == null || accessToken.isEmpty) return;
          final request = http.Request('GET', _baseUri.resolve('machines/realtime'))
            ..headers.addAll({'Accept': 'text/event-stream', 'Authorization': 'Bearer $accessToken'});
          final response = await client.send(request).timeout(_timeout);
          if (closed) return;
          if (response.statusCode == 401) {
            await _refreshAccessToken();
            continue;
          }
          if (response.statusCode != 200) throw http.ClientException('SSE HTTP ${response.statusCode}');
          delay = const Duration(seconds: 2);
          subscription = sseData(response.stream).listen((data) {
            if (isMachineStatusEvent(data) && !controller.isClosed) controller.add(null);
          });
          await subscription!.asFuture<void>();
        } on Object {
          // Koneksi putus atau gagal: coba lagi dengan jeda yang makin panjang.
        }
        if (closed) return;
        await Future<void>.delayed(delay);
        delay = delay * 2 > const Duration(seconds: 60) ? const Duration(seconds: 60) : delay * 2;
      }
    }

    controller = StreamController<void>(
      onListen: () => unawaited(connect()),
      onCancel: () async {
        closed = true;
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<List<AppNotification>> notifications() async {
    final rows = _asList(await _request('GET', 'notifications'));
    return rows.map((row) {
      final json = _asMap(row);
      final kind = _enumValue(NotificationKind.values, _stringValue(json['kind']).toLowerCase(), (value) => value.name, 'notification kind');
      return AppNotification(
        id: _stringValue(json['id']),
        kind: kind,
        title: _stringValue(json['title']),
        body: _stringValue(json['body']),
        createdAt: _dateValue(json['createdAt']),
        read: json['read'] == true,
        depositId: _optionalString(json['depositId']),
      );
    }).toList();
  }

  @override
  Future<void> registerPushToken(String token) async {
    await _request('POST', 'notifications/device-token', body: {'token': token});
  }

  @override
  Future<void> unregisterPushToken(String token) async {
    await _request('DELETE', 'notifications/device-token', body: {'token': token});
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _request('POST', 'notifications/${Uri.encodeComponent(id)}/read');
  }

  @override
  Future<void> markAllNotificationsRead() async {
    await _request('POST', 'notifications/read-all');
  }

  @override
  Future<Rates> updateRates({required int organikPerKg, required int anorganikPerKg}) async {
    final response = await _request('PUT', 'admin/rates', body: {'organikPerKg': organikPerKg, 'anorganikPerKg': anorganikPerKg});
    return _ratesFromJson(_asMap(response));
  }

  @override
  Future<void> resetMachine(String machineId) async {
    await _request('POST', 'machines/${Uri.encodeComponent(machineId)}/command', body: {'command': 'reset_gangguan'});
  }

  @override
  Future<void> configureMachine(String machineId, {required String name, required String location}) async {
    await _request('PUT', 'admin/machines/${Uri.encodeComponent(machineId)}', body: {'name': name, 'location': location});
  }

  @override
  Future<List<AdminUserSummary>> adminUsers() async {
    final rows = _asList(await _request('GET', 'admin/users'));
    return rows.map((row) {
      final json = _asMap(row);
      return AdminUserSummary(
        id: _stringValue(json['id']),
        name: _stringValue(json['name']),
        email: _stringValue(json['email']),
        role: _stringValue(json['role'], fallback: 'user'),
        active: json['active'] != false,
      );
    }).toList();
  }

  @override
  Future<void> createAdminUser({
    required String nik,
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    await _request('POST', 'admin/users', body: {'nik': nik, 'name': name, 'email': email, 'password': password, 'role': role});
  }

  @override
  Future<void> updateAdminUser(String id, {String? name, String? email, String? role, String? password, bool? active}) async {
    final body = <String, Object?>{};
    if (name != null) body['name'] = name;
    if (email != null) body['email'] = email;
    if (role != null) body['role'] = role;
    if (password != null) body['password'] = password;
    if (active != null) body['active'] = active;
    await _request('PATCH', 'admin/users/${Uri.encodeComponent(id)}', body: body);
  }

  @override
  Future<void> deleteAdminUser(String id) async {
    await _request('DELETE', 'admin/users/${Uri.encodeComponent(id)}');
  }

  @override
  Future<List<AdminHistoryRecord>> adminHistory() async {
    final rows = _asList(await _request('GET', 'admin/history'));
    return rows.map((row) => _adminRecordFromJson(_asMap(row))).toList();
  }

  @override
  Future<AdminHistoryPage> adminHistoryPage({String? cursor, int limit = 50}) async {
    final query = <String, String>{'paged': 'true', 'limit': '$limit'};
    if (cursor != null) query['cursor'] = cursor;
    final response = _asMap(await _request('GET', 'admin/history', query: query));
    return AdminHistoryPage(
      items: _asList(response['data']).map((row) => _adminRecordFromJson(_asMap(row))).toList(),
      nextCursor: _optionalString(response['nextCursor']),
    );
  }

  @override
  Future<List<DailyWeight>> adminDailyWeights({int days = 7}) async {
    final rows = _asList(await _request('GET', 'admin/stats/daily', query: {'days': '$days'}));
    return rows.map((row) {
      final json = _asMap(row);
      final parts = _stringValue(json['date']).split('-').map(int.parse).toList();
      return DailyWeight(date: DateTime.utc(parts[0], parts[1], parts[2]), weightKg: _doubleValue(json['weightKg']));
    }).toList();
  }

  AdminHistoryRecord _adminRecordFromJson(Map<String, dynamic> json) => AdminHistoryRecord(
    id: _stringValue(json['id']),
    userId: _stringValue(json['userId'], fallback: '-'),
    userName: _stringValue(json['userName'], fallback: 'Pengguna tidak diketahui'),
    machine: _stringValue(json['machine'], fallback: '-'),
    type: _stringValue(json['type'], fallback: '-'),
    weightKg: _doubleValue(json['weightKg']),
    points: _intValue(json['points']),
    time: _dateValue(json['time']),
  );

  Future<Object?> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authenticated = true,
    bool retryAfterRefresh = true,
  }) async {
    final uri = _baseUri.resolve(path).replace(queryParameters: query);
    try {
      final response = await _send(method, uri, body: body, authenticated: authenticated);
      final result = _decodeResponse(response);
      if (response.statusCode == 401 && authenticated && retryAfterRefresh && path != 'auth/refresh' && _asMap(result)['code'] == 'UNAUTHORIZED') {
        await _refreshAccessToken();
        return await _request(method, path, query: query, body: body, authenticated: authenticated, retryAfterRefresh: false);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = _asMap(result);
        final message = _stringValue(error['message'], fallback: 'Permintaan ke server gagal.');
        final field = response.statusCode == 401 ? 'unauthorized' : _fieldFromDetails(error['details']);
        throw AppException(message, field: field);
      }
      return result;
    } on http.ClientException {
      throw const AppException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } on TimeoutException {
      throw const AppException('Server terlalu lama merespons. Coba lagi.');
    } on FormatException {
      throw const AppException('Respons server tidak valid. Coba lagi nanti.');
    }
  }

  Future<http.Response> _send(String method, Uri uri, {Object? body, required bool authenticated}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (authenticated) {
      final accessToken = await secureStorage.read(key: _accessTokenKey);
      if (accessToken == null || accessToken.isEmpty) {
        throw const AppException('Sesi berakhir. Silakan masuk kembali.', field: 'unauthorized');
      }
      headers['Authorization'] = 'Bearer $accessToken';
    }
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await client.send(request).timeout(_timeout);
    return http.Response.fromStream(streamed).timeout(_timeout);
  }

  Future<void> _refreshAccessToken() async {
    final existing = _refreshing;
    if (existing != null) {
      await existing;
      return;
    }
    final refresh = _refreshTokens();
    _refreshing = refresh;
    try {
      await refresh;
    } finally {
      _refreshing = null;
    }
  }

  Future<void> _refreshTokens() async {
    final refreshToken = await secureStorage.read(key: _refreshTokenKey);
    if (refreshToken == null || refreshToken.isEmpty) {
      await _clearTokens();
      throw const AppException('Sesi berakhir. Silakan masuk kembali.', field: 'unauthorized');
    }
    try {
      final response = await _send('POST', _baseUri.resolve('auth/refresh'), body: {'refreshToken': refreshToken}, authenticated: false);
      final result = _decodeResponse(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await _clearTokens();
        throw const AppException('Sesi berakhir. Silakan masuk kembali.', field: 'unauthorized');
      }
      await _saveTokens(_asMap(result));
    } on http.ClientException {
      throw const AppException('Tidak dapat memperbarui sesi. Periksa koneksi internet Anda.');
    } on TimeoutException {
      throw const AppException('Server terlalu lama merespons saat memperbarui sesi.');
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> response) async {
    final access = _stringValue(response['accessToken']);
    final refresh = _stringValue(response['refreshToken']);
    await secureStorage.write(key: _accessTokenKey, value: access);
    await secureStorage.write(key: _refreshTokenKey, value: refresh);
  }

  Future<void> _clearTokens() async {
    await secureStorage.delete(key: _accessTokenKey);
    await secureStorage.delete(key: _refreshTokenKey);
  }

  Object? _decodeResponse(http.Response response) {
    if (response.body.isEmpty) return <String, Object?>{};
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> && decoded is! List<dynamic>) {
      throw const FormatException('Expected JSON object or array.');
    }
    return decoded;
  }

  String? _fieldFromDetails(Object? details) {
    if (details is List && details.isNotEmpty && details.first is Map) {
      final field = (details.first as Map)['field'];
      if (field is String) return field;
    }
    return null;
  }

  AppUser _userFromJson(Map<String, dynamic> json) {
    final cardJson = json['card'];
    return AppUser(
      id: _stringValue(json['id']),
      nim: json['nim'] == null ? null : _stringValue(json['nim']),
      name: _stringValue(json['name']),
      email: _stringValue(json['email']),
      role: _enumValue(UserRole.values, _stringValue(json['role']), (value) => value.name, 'user role'),
      card: cardJson is Map
          ? CardLink(
              linkedAt: _dateValue(cardJson['linkedAt']),
              uidHashSuffix: _stringValue(cardJson['uidHashSuffix'], fallback: ''),
            )
          : null,
    );
  }

  Deposit _depositFromJson(Map<String, dynamic> json) => Deposit(
    transactionId: _stringValue(json['transactionId']),
    machineId: _stringValue(json['machineId']),
    machineName: _stringValue(json['machineName'], fallback: ''),
    type: _enumValue(WasteType.values, _stringValue(json['type']).toLowerCase(), (value) => value.name, 'waste type'),
    itemLabel: _stringValue(json['itemLabel'], fallback: ''),
    weightG: _intValue(json['weightG']),
    points: _intValue(json['points']),
    ratePerKg: _intValue(json['ratePerKg']),
    deviceTime: _dateValue(json['deviceTime']),
    receivedAt: _dateValue(json['receivedAt']),
    status: _enumValue(DepositStatus.values, _stringValue(json['status']).toLowerCase(), (value) => value.name, 'deposit status'),
    photoUrl: _optionalString(json['photoUrl']),
  );

  Rates _ratesFromJson(Map<String, dynamic> json) => Rates(
    organikPerKg: _intValue(json['organikPerKg']),
    anorganikPerKg: _intValue(json['anorganikPerKg']),
    updatedAt: _dateValue(json['updatedAt']),
  );

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((key, value) => MapEntry(key.toString(), value));
    throw const FormatException('Expected a JSON object.');
  }

  static List<dynamic> _asList(Object? value) {
    if (value is List<dynamic>) return value;
    throw const FormatException('Expected a JSON list.');
  }

  static String _stringValue(Object? value, {String? fallback}) {
    if (value is String) return value;
    if (fallback != null) return fallback;
    throw const FormatException('Expected a string.');
  }

  static String? _optionalString(Object? value) => value == null ? null : _stringValue(value);

  static int _intValue(Object? value, {int? fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (fallback != null) return fallback;
    throw const FormatException('Expected an integer.');
  }

  static double _doubleValue(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.parse(value);
    throw const FormatException('Expected a number.');
  }

  static DateTime _dateValue(Object? value) {
    if (value is String) return DateTime.parse(value).toUtc();
    throw const FormatException('Expected an ISO-8601 date.');
  }

  static T _enumValue<T>(Iterable<T> values, String name, String Function(T) getName, String label) {
    for (final value in values) {
      if (getName(value) == name) return value;
    }
    throw FormatException('Unknown $label: $name');
  }
}

/// Mengurai aliran Server-Sent Events menjadi payload `data:` per event (event dipisah baris kosong).
Stream<String> sseData(Stream<List<int>> bytes) async* {
  final buffer = <String>[];
  await for (final line in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (buffer.isNotEmpty) yield buffer.join('\n');
      buffer.clear();
    } else if (line.startsWith('data:')) {
      buffer.add(line.substring(5).trimLeft());
    }
  }
}

/// Hanya event telemetri berjenis `status` yang mengubah tampilan status mesin.
bool isMachineStatusEvent(String data) {
  try {
    final decoded = jsonDecode(data);
    return decoded is Map && decoded['kind'] == 'status';
  } on FormatException {
    return false;
  }
}
