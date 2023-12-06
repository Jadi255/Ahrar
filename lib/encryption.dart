  import 'package:crypton/crypton.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future generateKeys() async {
    RSAKeypair rsaKeypair = RSAKeypair.fromRandom();
    final prefs = await SharedPreferences.getInstance();
    var privateKey = rsaKeypair.privateKey;
    var publicKey = rsaKeypair.publicKey;
    prefs.setString("privateKey", privateKey.toPEM());
    prefs.setString("publicKey", publicKey.toPEM());
  }

  Future<String> encrypt(message) async {
    final prefs = await SharedPreferences.getInstance();
    var key = await prefs.getString('publicKey');
    var publicKey = RSAPublicKey.fromPEM(key!);

    String encrypted = publicKey.encrypt(message);

    return encrypted;
  }

  Future<String> decrypt(message) async {
    final prefs = await SharedPreferences.getInstance();
    var privateKeyString = await prefs.getString('privateKey');
    var privateKey = RSAPrivateKey.fromPEM(privateKeyString!);

    String decrypted = privateKey.decrypt(message);
    return decrypted;
  }

