/* MIT License
*
* Copyright (C) 2019, 2020, 2021 Famedly GmbH
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../sendingnetworkdart_api_lite.dart';
import 'generated/api.dart';

enum RequestType { GET, POST, PUT, DELETE }

class SDNApi extends Api {
  /// The node this client is communicating with.
  Uri? get node => baseUri;

  // set node(Uri? uri) => baseUri = uri;

  set node(Uri? uri) {
    // print("set ${uri.uri}")
    // baseUri = sdnnode;
  }

  set sdnnode(Uri? uri) {
    baseUri = uri;
  }

  /// This is the access token for the sdn client. When it is undefined, then
  /// the user needs to sign in first.
  String? get accessToken => bearerToken;

  set accessToken(String? token) => bearerToken = token;

  @override
  Never unexpectedResponse(http.BaseResponse response, Uint8List body) {
    if (response.statusCode >= 400 && response.statusCode < 500) {
      final resp = json.decode(utf8.decode(body));
      if (resp is Map<String, Object?>) {
        throw SDNException.fromJson(resp);
      }
    }
    super.unexpectedResponse(response, body);
  }

  SDNApi({
    Uri? node,
    Uri? sdnnode,
    String? accessToken,
    http.Client? httpClient,
  }) : super(
            httpClient: httpClient, baseUri: sdnnode, bearerToken: accessToken);

  /// Used for all SDN json requests using the [c2s API](https://sdn.org/docs/spec/client_server/r0.6.0.html).
  ///
  /// Throws: FormatException, SDNException
  ///
  /// You must first set [this.node] and for some endpoints also
  /// [this.accessToken] before you can use this! For example to send a
  /// message to a SDN room with the id '!fjd823j:example.com' you call:
  /// ```
  /// final resp = await request(
  ///   RequestType.PUT,
  ///   '/r0/rooms/!fjd823j:example.com/send/m.room.message/$txnId',
  ///   data: {
  ///     'msgtype': 'm.text',
  ///     'body': 'hello'
  ///   }
  ///  );
  /// ```
  ///
  Future<Map<String, Object?>> request(
    RequestType type,
    String action, {
    dynamic data = '',
    String contentType = 'application/json',
    Map<String, Object?>? query,
  }) async {
    if (node == null) {
      throw ('No node specified.');
    }
    dynamic json;
    (data is! String) ? json = jsonEncode(data) : json = data;
    if (data is List<int> || action.startsWith('/media/v3/upload')) json = data;

    final url =
        node!.resolveUri(Uri(path: '_api$action', queryParameters: query));

    final headers = <String, String>{};
    if (type == RequestType.PUT || type == RequestType.POST) {
      headers['Content-Type'] = contentType;
    }
    if (accessToken != null) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    late http.Response resp;
    Map<String, Object?>? jsonResp = <String, Object?>{};
    try {
      switch (type) {
        case RequestType.GET:
          resp = await httpClient.get(url, headers: headers);
          break;
        case RequestType.POST:
          resp = await httpClient.post(url, body: json, headers: headers);
          break;
        case RequestType.PUT:
          resp = await httpClient.put(url, body: json, headers: headers);
          break;
        case RequestType.DELETE:
          resp = await httpClient.delete(url, headers: headers);
          break;
      }
      var respBody = resp.body;
      try {
        respBody = utf8.decode(resp.bodyBytes);
      } catch (_) {
        // No-OP
      }
      if (resp.statusCode >= 500 && resp.statusCode < 600) {
        throw Exception(respBody);
      }
      var jsonString = String.fromCharCodes(respBody.runes);
      if (jsonString.startsWith('[') && jsonString.endsWith(']')) {
        jsonString = '{"chunk":$jsonString}';
      }
      jsonResp = jsonDecode(jsonString)
          as Map<String, Object?>?; // May throw FormatException
    } catch (e, s) {
      throw SDNConnectionException(e, s);
    }
    if (resp.statusCode >= 400 && resp.statusCode < 500) {
      throw SDNException(resp);
    }

    return jsonResp!;
  }

  /// Publishes end-to-end encryption keys for the device.
  /// https://sdn.org/docs/spec/client_server/r0.6.1#post-sdn-client-r0-keys-query
  Future<Map<String, int>> uploadKeys(
      {SDNDeviceKeys? deviceKeys,
      Map<String, Object?>? oneTimeKeys,
      Map<String, Object?>? fallbackKeys}) async {
    final response = await request(
      RequestType.POST,
      '/client/v3/keys/upload',
      data: {
        if (deviceKeys != null) 'device_keys': deviceKeys.toJson(),
        if (oneTimeKeys != null) 'one_time_keys': oneTimeKeys,
        if (fallbackKeys != null) ...{
          'fallback_keys': fallbackKeys,
          'org.sdn.msc2732.fallback_keys': fallbackKeys,
        },
      },
    );
    return Map<String, int>.from(response['one_time_key_counts'] as Map);
  }

  /// This endpoint allows the creation, modification and deletion of pushers
  /// for this user ID. The behaviour of this endpoint varies depending on the
  /// values in the JSON body.
  ///
  /// See [deletePusher] to issue requests with `kind: null`.
  ///
  /// https://sdn.org/docs/spec/client_server/r0.6.1#post-sdn-client-r0-pushers-set
  Future<void> postPusher(Pusher pusher, {bool? append}) async {
    final data = pusher.toJson();
    if (append != null) {
      data['append'] = append;
    }
    await request(
      RequestType.POST,
      '/client/v3/pushers/set',
      data: data,
    );
    return;
  }

  /// Variant of postPusher operation that deletes pushers by setting `kind: null`.
  ///
  /// https://sdn.org/docs/spec/client_server/r0.6.1#post-sdn-client-r0-pushers-set
  Future<void> deletePusher(PusherId pusher) async {
    final data = PusherData.fromJson(pusher.toJson()).toJson();
    data['kind'] = null;
    await request(
      RequestType.POST,
      '/client/v3/pushers/set',
      data: data,
    );
    return;
  }

  /// This API provides credentials for the client to use when initiating
  /// calls.
  @override
  Future<TurnServerCredentials> getTurnServer() async {
    final json = await request(RequestType.GET, '/client/v3/voip/turnServer');

    // fix invalid responses from synapse
    // https://github.com/sdn-org/synapse/pull/10922
    final ttl = json['ttl'];
    if (ttl is double) {
      json['ttl'] = ttl.toInt();
    }

    return TurnServerCredentials.fromJson(json);
  }

  @Deprecated('Use [deleteRoomKeyBySessionId] instead')
  Future<RoomKeysUpdateResponse> deleteRoomKeysBySessionId(
      String roomId, String sessionId, String version) async {
    return deleteRoomKeyBySessionId(roomId, sessionId, version);
  }

  @Deprecated('Use [deleteRoomKeyBySessionId] instead')
  Future<RoomKeysUpdateResponse> putRoomKeysBySessionId(String roomId,
      String sessionId, String version, KeyBackupData data) async {
    return putRoomKeyBySessionId(roomId, sessionId, version, data);
  }

  @Deprecated('Use [getRoomKeyBySessionId] instead')
  Future<KeyBackupData> getRoomKeysBySessionId(
      String roomId, String sessionId, String version) async {
    return getRoomKeyBySessionId(roomId, sessionId, version);
  }
}
