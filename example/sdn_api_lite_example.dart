// @dart=2.9
import 'package:sendingnetworkdart_api_lite/src/sdn_api.dart';

void main() async {
  final api = SDNApi(node: Uri.parse('https://sdn.org'));
  final capabilities = await api.requestServerCapabilities();
  print(capabilities.toJson());
}
