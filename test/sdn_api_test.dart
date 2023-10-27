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

import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:sendingnetworkdart_api_lite/fake_sdn_api.dart';
import 'package:sendingnetworkdart_api_lite/sendingnetworkdart_api_lite.dart';

const emptyRequest = <String, Object?>{};

void main() {
  /// All Tests related to device keys
  group('SDN API', () {
    test('Logger', () async {
      Logs().level = Level.verbose;
      Logs().v('Test log');
      Logs().d('Test log');
      Logs().w('Test log');
      Logs().e('Test log');
      Logs().wtf('Test log');
      Logs().v('Test log', Exception('There has been a verbose'));
      Logs().d('Test log', Exception('Test'));
      Logs().w('Test log', Exception('Very bad error'));
      Logs().e('Test log', Exception('Test'), StackTrace.current);
      Logs().wtf('Test log', Exception('Test'), StackTrace.current);
    });
    Logs().level = Level.error;
    final sdnApi = SDNApi(
      httpClient: FakeSDNApi(),
    );
    test('SDNException test', () async {
      final exception = SDNException.fromJson({
        'flows': [
          {
            'stages': ['example.type.foo']
          }
        ],
        'params': {
          'example.type.baz': {'example_key': 'foobar'}
        },
        'session': 'xxxxxxyz',
        'completed': ['example.type.foo']
      });
      expect(exception.authenticationFlows!.first.stages.first,
          'example.type.foo');
      expect(exception.authenticationParams!['example.type.baz'],
          {'example_key': 'foobar'});
      expect(exception.session, 'xxxxxxyz');
      expect(exception.completedAuthenticationFlows, ['example.type.foo']);
      expect(exception.requireAdditionalAuthentication, true);
      expect(exception.retryAfterMs, null);
      expect(exception.error, SDNError.M_FORBIDDEN);
      expect(exception.errcode, 'M_FORBIDDEN');
      expect(exception.errorMessage, 'Require additional authentication');
    });
    test('triggerNotFoundError', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      bool error;
      error = false;
      try {
        await sdnApi.request(RequestType.GET, '/fake/path');
      } catch (_) {
        error = true;
      }
      expect(error, true);
      error = false;
      try {
        await sdnApi.request(RequestType.POST, '/fake/path');
      } catch (_) {
        error = true;
      }
      expect(error, true);
      error = false;
      try {
        await sdnApi.request(RequestType.PUT, '/fake/path');
      } catch (_) {
        error = true;
      }
      expect(error, true);
      error = false;
      try {
        await sdnApi.request(RequestType.DELETE, '/fake/path');
      } catch (_) {
        error = true;
      }
      expect(error, true);
      error = false;
      try {
        await sdnApi.request(RequestType.GET, '/path/to/auth/error/');
      } catch (exception) {
        expect(exception is SDNException, true);
        expect((exception as SDNException).errcode, 'M_FORBIDDEN');
        expect(exception.error, SDNError.M_FORBIDDEN);
        expect(exception.errorMessage, 'Blabla');
        expect(exception.requireAdditionalAuthentication, false);
        expect(exception.toString(), 'M_FORBIDDEN: Blabla');
        error = true;
      }
      expect(error, true);
      sdnApi.node = null;
    });
    test('getSupportedVersions', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      final supportedVersions = await sdnApi.getVersions();
      expect(supportedVersions.versions.contains('r0.5.0'), true);
      expect(supportedVersions.unstableFeatures!['m.lazy_load_members'], true);
      expect(FakeSDNApi.api['GET']!['/client/versions']!.call(emptyRequest),
          supportedVersions.toJson());
      sdnApi.node = null;
    });
    test('getWellKnownInformation', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      final wellKnownInformation = await sdnApi.getWellknown();
      expect(wellKnownInformation.mNode.baseUrl,
          Uri.parse('https://fakeserver.notexisting'));
      expect(wellKnownInformation.toJson(), {
        'm.node': {'base_url': 'https://fakeserver.notexisting'},
        'm.identity_server': {
          'base_url': 'https://identity.fakeserver.notexisting'
        },
        'org.example.custom.property': {
          'app_url': 'https://custom.app.fakeserver.notexisting'
        }
      });
    });
    test('getLoginTypes', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      final loginTypes = await sdnApi.getLoginFlows();
      expect(loginTypes?.first.type, 'm.login.password');
      expect(FakeSDNApi.api['GET']!['/client/v3/login']!.call(emptyRequest),
          {'flows': loginTypes?.map((x) => x.toJson()).toList()});
      sdnApi.node = null;
    });
    test('login', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      final loginResponse = await sdnApi.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: 'username'),
      );
      expect(FakeSDNApi.api['POST']!['/client/v3/login']!.call(emptyRequest),
          loginResponse.toJson());
      sdnApi.node = null;
    });
    test('logout', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      await sdnApi.logout();
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('logoutAll', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      await sdnApi.logoutAll();
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('register', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      final registerResponse =
          await sdnApi.register(kind: AccountKind.guest, username: 'test');
      expect(
          FakeSDNApi.api['POST']!['/client/v3/register?kind=guest']!
              .call(emptyRequest),
          registerResponse.toJson());
      sdnApi.node = null;
    });
    test('requestTokenToRegisterEmail', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      final response = await sdnApi.requestTokenToRegisterEmail(
        'alice@example.com',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      expect(
          FakeSDNApi.api['POST']!['/client/v3/register/email/requestToken']!
              .call(emptyRequest),
          response.toJson());
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestTokenToRegisterMSISDN', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      final response = await sdnApi.requestTokenToRegisterMSISDN(
        'en',
        '1234',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      expect(
          FakeSDNApi.api['POST']!['/client/v3/register/email/requestToken']!
              .call(emptyRequest),
          response.toJson());
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('changePassword', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      await sdnApi.changePassword(
        '1234',
        auth: AuthenticationData.fromJson({
          'type': 'example.type.foo',
          'session': 'xxxxx',
          'example_credential': 'verypoorsharedsecret'
        }),
      );
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestTokenToResetPasswordEmail', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      await sdnApi.requestTokenToResetPasswordEmail(
        'alice@example.com',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestTokenToResetPasswordMSISDN', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      await sdnApi.requestTokenToResetPasswordMSISDN(
        'en',
        '1234',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('deactivateAccount', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      final response = await sdnApi.deactivateAccount(
        idServer: 'https://example.com',
        auth: AuthenticationData.fromJson({
          'type': 'example.type.foo',
          'session': 'xxxxx',
          'example_credential': 'verypoorsharedsecret'
        }),
      );
      expect(response, IdServerUnbindResult.success);
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('usernameAvailable', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      final loginResponse = await sdnApi.checkUsernameAvailability('testuser');
      expect(loginResponse, true);
      sdnApi.node = null;
    });
    test('getThirdPartyIdentifiers', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      final response = await sdnApi.getAccount3PIDs();
      expect(
          FakeSDNApi.api['GET']!['/client/v3/account/3pid']!.call(emptyRequest),
          {'threepids': response?.map((t) => t.toJson()).toList()});
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('addThirdPartyIdentifier', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      await sdnApi.add3PID('1234', '1234',
          auth: AuthenticationData.fromJson({'type': 'm.login.dummy'}));
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('bindThirdPartyIdentifier', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      await sdnApi.bind3PID(
        '1234',
        '1234',
        'https://example.com',
        '1234',
      );
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('deleteThirdPartyIdentifier', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      final response = await sdnApi.delete3pidFromAccount(
        'alice@example.com',
        ThirdPartyIdentifierMedium.email,
        idServer: 'https://example.com',
      );
      expect(response, IdServerUnbindResult.success);
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('unbindThirdPartyIdentifier', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      final response = await sdnApi.unbind3pidFromAccount(
        'alice@example.com',
        ThirdPartyIdentifierMedium.email,
        idServer: 'https://example.com',
      );
      expect(response, IdServerUnbindResult.success);
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestTokenTo3PIDEmail', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      await sdnApi.requestTokenTo3PIDEmail(
        'alice@example.com',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestTokenTo3PIDMSISDN', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      await sdnApi.requestTokenTo3PIDMSISDN(
        'en',
        '1234',
        '1234',
        1,
        nextLink: 'https://example.com',
        idServer: 'https://example.com',
        idAccessToken: '1234',
      );
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestTokenTo3PIDMSISDN', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      final response = await sdnApi.getTokenOwner();
      expect(response.userId, 'alice@example.com');
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('getCapabilities', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      final response = await sdnApi.getCapabilities();
      expect(
          FakeSDNApi.api['GET']!['/client/v3/capabilities']!.call(emptyRequest),
          {'capabilities': response.toJson()});
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('uploadFilter', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      final response = await sdnApi.defineFilter('alice@example.com', Filter());
      expect(response, '1234');
      final filter = Filter(
        room: RoomFilter(
          notRooms: ['!1234'],
          rooms: ['!1234'],
          ephemeral: StateFilter(
            limit: 10,
            senders: ['@alice:example.com'],
            types: ['type1'],
            notTypes: ['type2'],
            notRooms: ['!1234'],
            notSenders: ['@bob:example.com'],
            lazyLoadMembers: true,
            includeRedundantMembers: false,
            containsUrl: true,
          ),
          includeLeave: true,
          state: StateFilter(),
          timeline: StateFilter(),
          accountData: StateFilter(limit: 10, types: ['type1']),
        ),
        presence: StateFilter(
          limit: 10,
          senders: ['@alice:example.com'],
          types: ['type1'],
          notRooms: ['!1234'],
          notSenders: ['@bob:example.com'],
        ),
        eventFormat: EventFormat.client,
        eventFields: ['type', 'content', 'sender'],
        accountData: EventFilter(
          types: ['m.accountdatatest'],
          notSenders: ['@alice:example.com'],
        ),
      );
      expect(filter.toJson(), {
        'room': {
          'not_rooms': ['!1234'],
          'rooms': ['!1234'],
          'ephemeral': {
            'limit': 10,
            'senders': ['@alice:example.com'],
            'types': ['type1'],
            'not_rooms': ['!1234'],
            'not_senders': ['@bob:example.com'],
            'not_types': ['type2'],
            'lazy_load_members': true,
            'include_redundant_members': false,
            'contains_url': true,
          },
          'account_data': {
            'limit': 10,
            'types': ['type1'],
          },
          'include_leave': true,
          'state': <String, Object?>{},
          'timeline': <String, Object?>{},
        },
        'presence': {
          'limit': 10,
          'senders': ['@alice:example.com'],
          'types': ['type1'],
          'not_rooms': ['!1234'],
          'not_senders': ['@bob:example.com']
        },
        'event_format': 'client',
        'event_fields': ['type', 'content', 'sender'],
        'account_data': {
          'types': ['m.accountdatatest'],
          'not_senders': ['@alice:example.com']
        },
      });
      await sdnApi.defineFilter(
        'alice@example.com',
        filter,
      );
      final filterMap = {
        'room': {
          'state': {
            'types': ['m.room.*'],
            'not_rooms': ['!726s6s6q:example.com']
          },
          'timeline': {
            'limit': 10,
            'types': ['m.room.message'],
            'not_rooms': ['!726s6s6q:example.com'],
            'not_senders': ['@spam:example.com']
          },
          'ephemeral': {
            'types': ['m.receipt', 'm.typing'],
            'not_rooms': ['!726s6s6q:example.com'],
            'not_senders': ['@spam:example.com']
          }
        },
        'presence': {
          'types': ['m.presence'],
          'not_senders': ['@alice:example.com']
        },
        'account_data': {
          'types': ['m.accountdatatest'],
          'not_senders': ['@alice:example.com']
        },
        'event_format': 'client',
        'event_fields': ['type', 'content', 'sender']
      };
      expect(filterMap, Filter.fromJson(filterMap).toJson());
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('downloadFilter', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      await sdnApi.getFilter('alice@example.com', '1234');
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('sync', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      final response = await sdnApi.sync(
        filter: '{}',
        since: '1234',
        fullState: false,
        setPresence: PresenceType.unavailable,
        timeout: 15,
      );
      expect(
          FakeSDNApi.api['GET']![
                  '/client/v3/sync?filter=%7B%7D&since=1234&full_state=false&set_presence=unavailable&timeout=15']!
              .call(emptyRequest) as Map?,
          response.toJson());
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestEvent', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final event =
          await sdnApi.getOneRoomEvent('!localpart:server.abc', '1234');
      expect(event.eventId, '143273582443PhrSn:example.org');
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('getRoomStateWithKey', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.getRoomStateWithKey(
        '!localpart:server.abc',
        'm.room.member',
        '@getme:example.com',
      );
      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestStates', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final states = await sdnApi.getRoomState('!localpart:server.abc');
      expect(states.length, 4);

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestMembers', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final states = await sdnApi.getMembersByRoom(
        '!localpart:server.abc',
        at: '1234',
        membership: Membership.join,
        notMembership: Membership.leave,
      );
      expect(states?.length, 1);

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestJoinedMembers', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final states = await sdnApi.getJoinedMembersByRoom(
        '!localpart:server.abc',
      );
      expect(states?.length, 1);
      expect(states?['@bar:example.com']?.toJson(), {
        'display_name': 'Bar',
        'avatar_url': 'mxc://riot.ovh/printErCATzZijQsSDWorRaK'
      });

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestMessages', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final timelineHistoryResponse = await sdnApi.getRoomEvents(
        '!localpart:server.abc',
        Direction.b,
        from: '1234',
        limit: 10,
        filter: '{"lazy_load_members":true}',
        to: '1234',
      );

      expect(
          FakeSDNApi.api['GET']![
                  '/client/v3/rooms/!localpart%3Aserver.abc/messages?from=1234&to=1234&dir=b&limit=10&filter=%7B%22lazy_load_members%22%3Atrue%7D']!
              .call(emptyRequest) as Map?,
          timelineHistoryResponse.toJson());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('sendState', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final eventId = await sdnApi.setRoomStateWithKey(
          '!localpart:server.abc', 'm.room.avatar', '', {'url': 'mxc://1234'});

      expect(eventId, 'YUwRidLecu:example.com');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('sendMessage', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final eventId = await sdnApi.sendMessage(
        '!localpart:server.abc',
        'm.room.message',
        '1234',
        {'body': 'hello world', 'msgtype': 'm.text'},
      );

      expect(eventId, 'YUwRidLecu:example.com');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('redact', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final eventId = await sdnApi.redactEvent(
        '!localpart:server.abc',
        '1234',
        '1234',
        reason: 'hello world',
      );

      expect(eventId, 'YUwRidLecu:example.com');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('createRoom', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final roomId = await sdnApi.createRoom(
        visibility: Visibility.public,
        roomAliasName: '#testroom:example.com',
        name: 'testroom',
        topic: 'just for testing',
        invite: ['@bob:example.com'],
        invite3pid: [],
        roomVersion: '2',
        creationContent: {},
        initialState: [],
        preset: CreateRoomPreset.publicChat,
        isDirect: false,
        powerLevelContentOverride: {},
      );

      expect(roomId, '!1234:fakeServer.notExisting');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('createRoomAlias', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setRoomAlias(
        '#testalias:example.com',
        '!1234:example.com',
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestRoomAliasInformation', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final roomAliasInformation = await sdnApi.getRoomIdByAlias(
        '#testalias:example.com',
      );

      expect(
          FakeSDNApi.api['GET']![
                  '/client/v3/directory/room/%23testalias%3Aexample.com']!
              .call(emptyRequest),
          roomAliasInformation.toJson());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('removeRoomAlias', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.deleteRoomAlias('#testalias:example.com');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestRoomAliases', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final list = await sdnApi.getLocalAliases('!localpart:example.com');
      expect(list.length, 3);

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestJoinedRooms', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final list = await sdnApi.getJoinedRooms();
      expect(list.length, 1);

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('inviteUser', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.inviteUser('!localpart:example.com', '@bob:example.com');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('joinRoom', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final roomId = '!localpart:example.com';
      final response = await sdnApi.joinRoomById(
        roomId,
        thirdPartySigned: ThirdPartySigned(
          sender: '@bob:example.com',
          mxid: '@alice:example.com',
          token: '1234',
          signatures: {
            'example.org': {'ed25519:0': 'some9signature'}
          },
        ),
      );
      expect(response, roomId);

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('joinRoomOrAlias', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final roomId = '!localpart:example.com';
      final response = await sdnApi.joinRoom(
        roomId,
        serverName: ['example.com', 'example.abc'],
        thirdPartySigned: ThirdPartySigned(
          sender: '@bob:example.com',
          mxid: '@alice:example.com',
          token: '1234',
          signatures: {
            'example.org': {'ed25519:0': 'some9signature'}
          },
        ),
      );
      expect(response, roomId);

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('leave', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.leaveRoom('!localpart:example.com');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('forget', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.forgetRoom('!localpart:example.com');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('kickFromRoom', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.kick(
        '!localpart:example.com',
        '@bob:example.com',
        reason: 'test',
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('banFromRoom', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.ban(
        '!localpart:example.com',
        '@bob:example.com',
        reason: 'test',
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('unbanInRoom', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.unban(
        '!localpart:example.com',
        '@bob:example.com',
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestRoomVisibility', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final visibility =
          await sdnApi.getRoomVisibilityOnDirectory('!localpart:example.com');
      expect(visibility, Visibility.public);

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('setRoomVisibility', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setRoomVisibilityOnDirectory('!localpart:example.com',
          visibility: Visibility.private);

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestPublicRooms', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getPublicRooms(
        limit: 10,
        since: '1234',
        server: 'example.com',
      );

      expect(
          FakeSDNApi.api['GET']![
                  '/client/v3/publicRooms?limit=10&since=1234&server=example.com']!
              .call(emptyRequest),
          response.toJson());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('searchPublicRooms', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.queryPublicRooms(
        limit: 10,
        since: '1234',
        server: 'example.com',
        filter: PublicRoomQueryFilter(
          genericSearchTerm: 'test',
        ),
        includeAllNetworks: false,
        thirdPartyInstanceId: 'id',
      );

      expect(
          FakeSDNApi.api['POST']!['/client/v3/publicRooms?server=example.com']!
              .call(emptyRequest),
          response.toJson());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('getSpaceHierarchy', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response =
          await sdnApi.getSpaceHierarchy('!gPxZhKUssFZKZcoCKY:neko.dev');

      expect(
          FakeSDNApi.api['GET']![
                  '/client/v1/rooms/${Uri.encodeComponent('!gPxZhKUssFZKZcoCKY:neko.dev')}/hierarchy']!
              .call(emptyRequest),
          response.toJson());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('searchUser', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.searchUserDirectory(
        'test',
        limit: 10,
      );

      expect(
          FakeSDNApi.api['POST']!['/client/v3/user_directory/search']!
              .call(emptyRequest),
          response.toJson());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('setDisplayname', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setDisplayName('@alice:example.com', 'Alice M');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestDisplayname', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.getDisplayName('@alice:example.com');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('setAvatarUrl', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setAvatarUrl(
        '@alice:example.com',
        Uri.parse('mxc://test'),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestAvatarUrl', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getAvatarUrl('@alice:example.com');
      expect(response, Uri.parse('mxc://test'));

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestProfile', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getUserProfile('@alice:example.com');
      expect(
          FakeSDNApi.api['GET']!['/client/v3/profile/%40alice%3Aexample.com']!
              .call(emptyRequest),
          response.toJson());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestTurnServerCredentials', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getTurnServer();
      expect(
          FakeSDNApi.api['GET']!['/client/v3/voip/turnServer']!
              .call(emptyRequest),
          response.toJson());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('sendTypingNotification', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setTyping(
        '@alice:example.com',
        '!localpart:example.com',
        true,
        timeout: 10,
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('sendReceiptMarker', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.postReceipt(
        '!localpart:example.com',
        ReceiptType.mRead,
        '\$1234:example.com',
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('sendReadMarker', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setReadMarker(
        '!localpart:example.com',
        mFullyRead: '\$1234:example.com',
        mRead: '\$1234:example.com',
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('sendPresence', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setPresence(
        '@alice:example.com',
        PresenceType.offline,
        statusMsg: 'test',
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestPresence', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getPresence(
        '@alice:example.com',
      );
      expect(
          FakeSDNApi.api['GET']![
                  '/client/v3/presence/${Uri.encodeComponent('@alice:example.com')}/status']!
              .call(emptyRequest),
          response.toJson());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('upload', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';
      final response =
          await sdnApi.uploadContent(Uint8List(0), filename: 'file.jpeg');
      expect(response, Uri.parse('mxc://example.com/AQwafuaFswefuhsfAFAgsw'));
      var throwsException = false;
      try {
        await sdnApi.uploadContent(Uint8List(0), filename: 'file.jpg');
      } catch (_) {
        throwsException = true;
      }
      expect(throwsException, true);
      sdnApi.node = null;
    });
    test('requestOpenGraphDataForUrl', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final openGraphData = await sdnApi.getUrlPreview(
        Uri.parse('https://sdn.org'),
        ts: 10,
      );
      expect(
          FakeSDNApi.api['GET']![
                  '/media/v3/preview_url?url=https%3A%2F%2Fsdn.org&ts=10']!
              .call(emptyRequest),
          openGraphData.toJson());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('getConfig', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getConfig();
      expect(response.mUploadSize, 50000000);

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('sendToDevice', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.sendToDevice('m.test', '1234', {
        '@alice:example.com': {
          'TLLBEANAAG': {'example_content_key': 'value'}
        }
      });

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestDevices', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final devices = await sdnApi.getDevices();
      expect(
          (FakeSDNApi.api['GET']!['/client/v3/devices']!.call(emptyRequest)
              as Map<String, Object?>?)?['devices'],
          devices?.map((i) => i.toJson()).toList());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestDevice', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.getDevice('QBUAZIFURK');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('setDeviceMetadata', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.updateDevice('QBUAZIFURK', displayName: 'test');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('deleteDevice', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.deleteDevice('QBUAZIFURK');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('deleteDevices', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.deleteDevices(['QBUAZIFURK']);

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('uploadDeviceKeys', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.uploadKeys(
        deviceKeys: SDNDeviceKeys(
          '@alice:example.com',
          'ABCD',
          ['caesar-chiffre'],
          {},
          {},
          unsigned: {},
        ),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestDeviceKeys', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.queryKeys(
        {
          '@alice:example.com': [],
        },
        timeout: 10,
        token: '1234',
      );
      expect(
          response.deviceKeys!['@alice:example.com']!['JLAFKJWSCS']!
              .deviceDisplayName,
          'Alices mobile phone');
      expect(
          FakeSDNApi.api['POST']!['/client/v3/keys/query']!
              .call({'device_keys': emptyRequest}),
          response.toJson());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestOneTimeKeys', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.claimKeys(
        {
          '@alice:example.com': {'JLAFKJWSCS': 'signed_curve25519'}
        },
        timeout: 10,
      );
      expect(
          FakeSDNApi.api['POST']!['/client/v3/keys/claim']!.call({
            'one_time_keys': {
              '@alice:example.com': {'JLAFKJWSCS': 'signed_curve25519'}
            }
          }),
          response.toJson());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestDeviceListsUpdate', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.getKeysChanges('1234', '1234');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('uploadCrossSigningKeys', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final masterKey = SDNCrossSigningKey.fromJson({
        'user_id': '@test:fakeServer.notExisting',
        'usage': ['master'],
        'keys': {
          'ed25519:82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8':
              '82mAXjsmbTbrE6zyShpR869jnrANO75H8nYY0nDLoJ8',
        },
        'signatures': <String, Map<String, String>>{},
      });
      final selfSigningKey = SDNCrossSigningKey.fromJson({
        'user_id': '@test:fakeServer.notExisting',
        'usage': ['self_signing'],
        'keys': {
          'ed25519:F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY':
              'F9ypFzgbISXCzxQhhSnXMkc1vq12Luna3Nw5rqViOJY',
        },
        'signatures': <String, Map<String, String>>{},
      });
      final userSigningKey = SDNCrossSigningKey.fromJson({
        'user_id': '@test:fakeServer.notExisting',
        'usage': ['user_signing'],
        'keys': {
          'ed25519:0PiwulzJ/RU86LlzSSZ8St80HUMN3dqjKa/orIJoA0g':
              '0PiwulzJ/RU86LlzSSZ8St80HUMN3dqjKa/orIJoA0g',
        },
        'signatures': <String, Map<String, String>>{},
      });
      await sdnApi.uploadCrossSigningKeys(
          masterKey: masterKey,
          selfSigningKey: selfSigningKey,
          userSigningKey: userSigningKey);
    });
    test('requestPushers', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getPushers();
      expect(
        FakeSDNApi.api['GET']!['/client/v3/pushers']!.call(<String, Object?>{}),
        {'pushers': response?.map((i) => i.toJson()).toList()},
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('setPusher', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.postPusher(
        Pusher(
          pushkey: '1234',
          appId: 'app.id',
          appDisplayName: 'appDisplayName',
          deviceDisplayName: 'deviceDisplayName',
          lang: 'en',
          data: PusherData(
              format: 'event_id_only', url: Uri.parse('https://sdn.org')),
          profileTag: 'tag',
          kind: 'http',
        ),
        append: true,
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestNotifications', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getNotifications(
        from: '1234',
        limit: 10,
        only: '1234',
      );
      expect(
        FakeSDNApi.api['GET']![
                '/client/v3/notifications?from=1234&limit=10&only=1234']!
            .call(<String, Object?>{}),
        response.toJson(),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestPushRules', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getPushRules();
      expect(
        FakeSDNApi.api['GET']!['/client/v3/pushrules']!
            .call(<String, Object?>{}),
        {'global': response.toJson()},
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestPushRule', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response =
          await sdnApi.getPushRule('global', PushRuleKind.content, 'nocake');
      expect(
        FakeSDNApi.api['GET']!['/client/v3/pushrules/global/content/nocake']!
            .call(<String, Object?>{}),
        response.toJson(),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('deletePushRule', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.deletePushRule('global', PushRuleKind.content, 'nocake');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('setPushRule', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setPushRule(
        'global',
        PushRuleKind.content,
        'nocake',
        [PushRuleAction.notify],
        before: '1',
        after: '2',
        conditions: [
          PushCondition(
            kind: 'event_match',
            key: 'key',
            pattern: 'pattern',
            is$: '+',
          )
        ],
        pattern: 'pattern',
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestPushRuleEnabled', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final enabled = await sdnApi.isPushRuleEnabled(
          'global', PushRuleKind.content, 'nocake');
      expect(enabled, true);

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('enablePushRule', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setPushRuleEnabled(
        'global',
        PushRuleKind.content,
        'nocake',
        true,
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestPushRuleActions', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final actions = await sdnApi.getPushRuleActions(
          'global', PushRuleKind.content, 'nocake');
      expect(actions.first, PushRuleAction.notify);

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('setPushRuleActions', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setPushRuleActions(
        'global',
        PushRuleKind.content,
        'nocake',
        [PushRuleAction.dontNotify],
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('globalSearch', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.search(Categories());

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('globalSearch', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response =
          await sdnApi.peekEvents(from: '1234', roomId: '!1234', timeout: 10);
      expect(
        FakeSDNApi.api['GET']![
                '/client/v3/events?from=1234&timeout=10&room_id=%211234']!
            .call(<String, Object?>{}),
        response.toJson(),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestRoomTags', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getRoomTags(
          '@alice:example.com', '!localpart:example.com');
      expect(
        FakeSDNApi.api['GET']![
                '/client/v3/user/%40alice%3Aexample.com/rooms/!localpart%3Aexample.com/tags']!
            .call(<String, Object?>{}),
        {'tags': response?.map((k, v) => MapEntry(k, v.toJson()))},
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('addRoomTag', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setRoomTag(
        '@alice:example.com',
        '!localpart:example.com',
        'testtag',
        order: 0.5,
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('addRoomTag', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.deleteRoomTag(
        '@alice:example.com',
        '!localpart:example.com',
        'testtag',
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('setAccountData', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setAccountData(
        '@alice:example.com',
        'test.account.data',
        {'foo': 'bar'},
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestAccountData', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.getAccountData(
        '@alice:example.com',
        'test.account.data',
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('setRoomAccountData', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.setAccountDataPerRoom(
        '@alice:example.com',
        '1234',
        'test.account.data',
        {'foo': 'bar'},
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestRoomAccountData', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.getAccountDataPerRoom(
        '@alice:example.com',
        '1234',
        'test.account.data',
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestWhoIsInfo', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getWhoIs('@alice:example.com');
      expect(
        FakeSDNApi.api['GET']!['/client/v3/admin/whois/%40alice%3Aexample.com']!
            .call(emptyRequest),
        response.toJson(),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestEventContext', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response =
          await sdnApi.getEventContext('1234', '1234', limit: 10, filter: '{}');
      expect(
        FakeSDNApi.api['GET']![
                '/client/v3/rooms/1234/context/1234?limit=10&filter=%7B%7D']!
            .call(emptyRequest),
        response.toJson(),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('reportEvent', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.reportContent(
        '1234',
        '1234',
        reason: 'test',
        score: -100,
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('getProtocols', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getProtocols();
      expect(
        FakeSDNApi.api['GET']!['/client/v3/thirdparty/protocols']!
            .call(emptyRequest),
        response.map((k, v) => MapEntry(k, v.toJson())),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('getProtocol', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.getProtocolMetadata('irc');
      expect(
        FakeSDNApi.api['GET']!['/client/v3/thirdparty/protocol/irc']!
            .call(emptyRequest),
        response.toJson(),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('queryLocationByProtocol', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.queryLocationByProtocol('irc');
      expect(
        FakeSDNApi.api['GET']!['/client/v3/thirdparty/location/irc']!
            .call(emptyRequest),
        response.map((i) => i.toJson()).toList(),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('queryUserByProtocol', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.queryUserByProtocol('irc');
      expect(
        FakeSDNApi.api['GET']!['/client/v3/thirdparty/user/irc']!
            .call(emptyRequest),
        response.map((i) => i.toJson()).toList(),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('queryLocationByAlias', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.queryLocationByAlias('1234');
      expect(
        FakeSDNApi.api['GET']!['/client/v3/thirdparty/location?alias=1234']!
            .call(emptyRequest),
        response.map((i) => i.toJson()).toList(),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('queryUserByID', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.queryUserByID('1234');
      expect(
        FakeSDNApi.api['GET']!['/client/v3/thirdparty/user?userid=1234']!
            .call(emptyRequest),
        response.map((i) => i.toJson()).toList(),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('requestOpenIdCredentials', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final response = await sdnApi.requestOpenIdToken('1234', {});
      expect(
        FakeSDNApi.api['POST']!['/client/v3/user/1234/openid/request_token']!
            .call(emptyRequest),
        response.toJson(),
      );

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('upgradeRoom', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.upgradeRoom('1234', '2');

      sdnApi.node = sdnApi.accessToken = null;
    });
    test('postRoomKeysVersion', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final algorithm = BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2;
      final authData = <String, Object?>{
        'public_key': 'GXYaxqhNhUK28zUdxOmEsFRguz+PzBsDlTLlF0O0RkM',
        'signatures': <String, Map<String, String>>{},
      };
      final ret = await sdnApi.postRoomKeysVersion(algorithm, authData);
      expect(
          (FakeSDNApi.api['POST']!['/client/v3/room_keys/version']!
              .call(emptyRequest) as Map<String, Object?>)['version'],
          ret);
    });
    test('getRoomKeysVersionCurrent', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final ret = await sdnApi.getRoomKeysVersionCurrent();
      expect(
          FakeSDNApi.api['GET']!['/client/v3/room_keys/version']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('putRoomKeysVersion', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final algorithm = BackupAlgorithm.mMegolmBackupV1Curve25519AesSha2;
      final authData = <String, Object?>{
        'public_key': 'GXYaxqhNhUK28zUdxOmEsFRguz+PzBsDlTLlF0O0RkM',
        'signatures': <String, Map<String, String>>{},
      };
      await sdnApi.putRoomKeysVersion('5', algorithm, authData);
    });
    test('deleteRoomKeys', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      await sdnApi.deleteRoomKeys('5');
    });
    test('putRoomKeyBySessionId', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final session = KeyBackupData.fromJson({
        'first_message_index': 0,
        'forwarded_count': 0,
        'is_verified': true,
        'session_data': {
          'ephemeral': 'fwRxYh+seqLykz5mQCLypJ4/59URdcFJ2s69OU1dGRc',
          'ciphertext':
              '19jkQYlbgdP+VL9DH3qY/Dvpk6onJZgf+6frZFl1TinPCm9OMK9AZZLuM1haS9XLAUK1YsREgjBqfl6T+Tq8JlJ5ONZGg2Wttt24sGYc0iTMZJ8rXcNDeKMZhM96ETyjufJSeYoXLqifiVLDw9rrVBmNStF7PskYp040em+0OZ4pF85Cwsdf7l9V7MMynzh9BoXqVUCBiwT03PNYH9AEmNUxXX+6ZwCpe/saONv8MgGt5uGXMZIK29phA3D8jD6uV/WOHsB8NjHNq9FrfSEAsl+dAcS4uiYie4BKSSeQN+zGAQqu1MMW4OAdxGOuf8WpIINx7n+7cKQfxlmc/Cgg5+MmIm2H0oDwQ+Xu7aSxp1OCUzbxQRdjz6+tnbYmZBuH0Ov2RbEvC5tDb261LRqKXpub0llg5fqKHl01D0ahv4OAQgRs5oU+4mq+H2QGTwIFGFqP9tCRo0I+aICawpxYOfoLJpFW6KvEPnM2Lr3sl6Nq2fmkz6RL5F7nUtzxN8OKazLQpv8DOYzXbi7+ayEsqS0/EINetq7RfCqgjrEUgfNWYuFXWqvUT8lnxLdNu+8cyrJqh1UquFjXWTw1kWcJ0pkokVeBtK9YysCnF1UYh/Iv3rl2ZoYSSLNtuvMSYlYHggZ8xV8bz9S3X2/NwBycBiWIy5Ou/OuSX7trIKgkkmda0xjBWEM1a2acVuqu2OFbMn2zFxm2a3YwKP//OlIgMg',
          'mac': 'QzKV/fgAs4U',
        },
      });
      final ret =
          await sdnApi.putRoomKeyBySessionId(roomId, sessionId, '5', session);
      expect(
          FakeSDNApi.api['PUT']![
                  '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}/${Uri.encodeComponent('ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU')}?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('getRoomKeyBySessionId', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final ret = await sdnApi.getRoomKeyBySessionId(roomId, sessionId, '5');
      expect(
          FakeSDNApi.api['GET']![
                  '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}/${Uri.encodeComponent('ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU')}?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('deleteRoomKeyBySessionId', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final ret = await sdnApi.deleteRoomKeyBySessionId(roomId, sessionId, '5');
      expect(
          FakeSDNApi.api['DELETE']![
                  '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}/${Uri.encodeComponent('ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU')}?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('putRoomKeysByRoomId', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final session = RoomKeyBackup.fromJson({
        'sessions': {
          sessionId: {
            'first_message_index': 0,
            'forwarded_count': 0,
            'is_verified': true,
            'session_data': {
              'ephemeral': 'fwRxYh+seqLykz5mQCLypJ4/59URdcFJ2s69OU1dGRc',
              'ciphertext':
                  '19jkQYlbgdP+VL9DH3qY/Dvpk6onJZgf+6frZFl1TinPCm9OMK9AZZLuM1haS9XLAUK1YsREgjBqfl6T+Tq8JlJ5ONZGg2Wttt24sGYc0iTMZJ8rXcNDeKMZhM96ETyjufJSeYoXLqifiVLDw9rrVBmNStF7PskYp040em+0OZ4pF85Cwsdf7l9V7MMynzh9BoXqVUCBiwT03PNYH9AEmNUxXX+6ZwCpe/saONv8MgGt5uGXMZIK29phA3D8jD6uV/WOHsB8NjHNq9FrfSEAsl+dAcS4uiYie4BKSSeQN+zGAQqu1MMW4OAdxGOuf8WpIINx7n+7cKQfxlmc/Cgg5+MmIm2H0oDwQ+Xu7aSxp1OCUzbxQRdjz6+tnbYmZBuH0Ov2RbEvC5tDb261LRqKXpub0llg5fqKHl01D0ahv4OAQgRs5oU+4mq+H2QGTwIFGFqP9tCRo0I+aICawpxYOfoLJpFW6KvEPnM2Lr3sl6Nq2fmkz6RL5F7nUtzxN8OKazLQpv8DOYzXbi7+ayEsqS0/EINetq7RfCqgjrEUgfNWYuFXWqvUT8lnxLdNu+8cyrJqh1UquFjXWTw1kWcJ0pkokVeBtK9YysCnF1UYh/Iv3rl2ZoYSSLNtuvMSYlYHggZ8xV8bz9S3X2/NwBycBiWIy5Ou/OuSX7trIKgkkmda0xjBWEM1a2acVuqu2OFbMn2zFxm2a3YwKP//OlIgMg',
              'mac': 'QzKV/fgAs4U',
            },
          },
        },
      });
      final ret = await sdnApi.putRoomKeysByRoomId(roomId, '5', session);
      expect(
          FakeSDNApi.api['PUT']![
                  '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('getRoomKeysByRoomId', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final ret = await sdnApi.getRoomKeysByRoomId(roomId, '5');
      expect(
          FakeSDNApi.api['GET']![
                  '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('deleteRoomKeysByRoomId', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final ret = await sdnApi.deleteRoomKeysByRoomId(roomId, '5');
      expect(
          FakeSDNApi.api['DELETE']![
                  '/client/v3/room_keys/keys/${Uri.encodeComponent('!726s6s6q:example.com')}?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('putRoomKeys', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final roomId = '!726s6s6q:example.com';
      final sessionId = 'ciM/JWTPrmiWPPZNkRLDPQYf9AW/I46bxyLSr+Bx5oU';
      final session = RoomKeys.fromJson({
        'rooms': {
          roomId: {
            'sessions': {
              sessionId: {
                'first_message_index': 0,
                'forwarded_count': 0,
                'is_verified': true,
                'session_data': {
                  'ephemeral': 'fwRxYh+seqLykz5mQCLypJ4/59URdcFJ2s69OU1dGRc',
                  'ciphertext':
                      '19jkQYlbgdP+VL9DH3qY/Dvpk6onJZgf+6frZFl1TinPCm9OMK9AZZLuM1haS9XLAUK1YsREgjBqfl6T+Tq8JlJ5ONZGg2Wttt24sGYc0iTMZJ8rXcNDeKMZhM96ETyjufJSeYoXLqifiVLDw9rrVBmNStF7PskYp040em+0OZ4pF85Cwsdf7l9V7MMynzh9BoXqVUCBiwT03PNYH9AEmNUxXX+6ZwCpe/saONv8MgGt5uGXMZIK29phA3D8jD6uV/WOHsB8NjHNq9FrfSEAsl+dAcS4uiYie4BKSSeQN+zGAQqu1MMW4OAdxGOuf8WpIINx7n+7cKQfxlmc/Cgg5+MmIm2H0oDwQ+Xu7aSxp1OCUzbxQRdjz6+tnbYmZBuH0Ov2RbEvC5tDb261LRqKXpub0llg5fqKHl01D0ahv4OAQgRs5oU+4mq+H2QGTwIFGFqP9tCRo0I+aICawpxYOfoLJpFW6KvEPnM2Lr3sl6Nq2fmkz6RL5F7nUtzxN8OKazLQpv8DOYzXbi7+ayEsqS0/EINetq7RfCqgjrEUgfNWYuFXWqvUT8lnxLdNu+8cyrJqh1UquFjXWTw1kWcJ0pkokVeBtK9YysCnF1UYh/Iv3rl2ZoYSSLNtuvMSYlYHggZ8xV8bz9S3X2/NwBycBiWIy5Ou/OuSX7trIKgkkmda0xjBWEM1a2acVuqu2OFbMn2zFxm2a3YwKP//OlIgMg',
                  'mac': 'QzKV/fgAs4U',
                },
              },
            },
          },
        },
      });
      final ret = await sdnApi.putRoomKeys('5', session);
      expect(
          FakeSDNApi.api['PUT']!['/client/v3/room_keys/keys?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('getRoomKeys', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final ret = await sdnApi.getRoomKeys('5');
      expect(
          FakeSDNApi.api['GET']!['/client/v3/room_keys/keys?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('deleteRoomKeys', () async {
      sdnApi.node = Uri.parse('https://fakeserver.notexisting');
      sdnApi.accessToken = '1234';

      final ret = await sdnApi.deleteRoomKeys('5');
      expect(
          FakeSDNApi.api['DELETE']!['/client/v3/room_keys/keys?version=5']!
              .call(emptyRequest),
          ret.toJson());
    });
    test('AuthenticationData', () {
      final json = {'session': '1234', 'type': 'm.login.dummy'};
      expect(AuthenticationData.fromJson(json).toJson(), json);
      expect(
          AuthenticationData(session: '1234', type: 'm.login.dummy').toJson(),
          json);
    });
    test('AuthenticationRecaptcha', () {
      final json = {
        'session': '1234',
        'type': 'm.login.recaptcha',
        'response': 'a',
      };
      expect(AuthenticationRecaptcha.fromJson(json).toJson(), json);
      expect(AuthenticationRecaptcha(session: '1234', response: 'a').toJson(),
          json);
    });
    test('AuthenticationToken', () {
      final json = {
        'session': '1234',
        'type': 'm.login.token',
        'token': 'a',
        'txn_id': '1'
      };
      expect(AuthenticationToken.fromJson(json).toJson(), json);
      expect(
          AuthenticationToken(session: '1234', token: 'a', txnId: '1').toJson(),
          json);
    });
    test('AuthenticationThreePidCreds', () {
      final json = {
        'type': 'm.login.email.identity',
        'threepid_creds': {
          'sid': '1',
          'client_secret': 'a',
          'id_server': 'sdn.org',
          'id_access_token': 'a',
        },
        'session': '1',
      };
      expect(AuthenticationThreePidCreds.fromJson(json).toJson(), json);
      expect(
          AuthenticationThreePidCreds(
            session: '1',
            type: AuthenticationTypes.emailIdentity,
            threepidCreds: ThreepidCreds(
              sid: '1',
              clientSecret: 'a',
              idServer: 'sdn.org',
              idAccessToken: 'a',
            ),
          ).toJson(),
          json);
    });
    test('AuthenticationIdentifier', () {
      final json = {'type': 'm.id.user'};
      expect(AuthenticationIdentifier.fromJson(json).toJson(), json);
      expect(AuthenticationIdentifier(type: 'm.id.user').toJson(), json);
    });
    test('AuthenticationPassword', () {
      final json = {
        'type': 'm.login.password',
        'identifier': {'type': 'm.id.user', 'user': 'a'},
        'password': 'a',
        'session': '1',
      };
      expect(AuthenticationPassword.fromJson(json).toJson(), json);
      expect(
          AuthenticationPassword(
            session: '1',
            password: 'a',
            identifier: AuthenticationUserIdentifier(user: 'a'),
          ).toJson(),
          json);
      json['identifier'] = {
        'type': 'm.id.thirdparty',
        'medium': 'a',
        'address': 'a',
      };
      expect(AuthenticationPassword.fromJson(json).toJson(), json);
      expect(
          AuthenticationPassword(
            session: '1',
            password: 'a',
            identifier:
                AuthenticationThirdPartyIdentifier(medium: 'a', address: 'a'),
          ).toJson(),
          json);
      json['identifier'] = {
        'type': 'm.id.phone',
        'country': 'a',
        'phone': 'a',
      };
      expect(AuthenticationPassword.fromJson(json).toJson(), json);
      expect(
          AuthenticationPassword(
            session: '1',
            password: 'a',
            identifier: AuthenticationPhoneIdentifier(country: 'a', phone: 'a'),
          ).toJson(),
          json);
    });
  });
}
