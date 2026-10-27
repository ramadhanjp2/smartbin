import 'dart:async';
import 'dart:convert';

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
    if (asAdmin && user.role != UserRole.admin) {
      await logout();
      throw const AppException('Akun ini tidak memiliki akses Admin / Teknisi.');
    }
    return user;
  }

  @override
  Future<AppUser> register({required String nim, required String name, required String email, required String password}) async {
    final response = _asMap(
      await _request('POST', 'auth/register', body: {'nim': nim, 'name': name, 'email': email, 'password': password}, authenticated: false),
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
  Future<Deposit> deposit(String transactionId) async {
    final result = await _request('GET', 'deposits/${Uri.encodeComponent(transactionId)}');
    return _depositFromJson(_asMap(result));
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
        name: _stringValue(json['name']),
        campus: _stringValue(json['campus'], fallback: ''),
        location: _stringValue(json['location'], fallback: ''),
        status: status,
        lastSeen: json['lastSeen'] == null ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true) : _dateValue(json['lastSeen']),
        organicFill: _intValue(json['organicFill']),
        inorganicFill: _intValue(json['inorganicFill']),
        organicCmLeft: 0,
        inorganicCmLeft: 0,
        temperatureC: 0,
        modules: const [],
      );
    }).toList();
  }

  @override
  Future<List<TelemetryLog>> telemetry(String machineId) async {
    throw const AppException('Data telemetri mesin belum tersedia dari API.');
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
    await _request('POST', 'machines/${Uri.encodeComponent(machineId)}/reset');
  }

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
      nim: _stringValue(json['nim']),
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

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    throw const FormatException('Expected an integer.');
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
