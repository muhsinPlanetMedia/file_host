import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final formData = await request.formData();
  final fileData = formData.files['file'];
  final folderName = formData.fields['folderName'];
  final secretKey = formData.fields['secretKey'];

  if (fileData == null || folderName == null || secretKey == null) {
    return Response(statusCode: 400, body: 'Missing file, folderName, or secretKey');
  }

  // Generate a random file name with the correct extension
  final fileExtension = fileData.name.split('.').last;
  final randomFileName = generateRandomFileName(folderName, secretKey, fileExtension);
  final filePath = 'uploads/$folderName/$randomFileName';

  // Ensure secret key is created before checking validity
  final secretKeyFile = File('uploads/$folderName/secretKey.txt');
  if (!await secretKeyFile.exists()) {
    await createSecretKey(folderName, secretKey);
  }

  if (!await checkIsValidSecretKey(folderName, secretKey)) {
    return Response(statusCode: 400, body: 'Invalid secret key');
  }

  // Ensure the uploads directory exists
  await Directory('uploads/$folderName').create(recursive: true);

  // Save the file to the server
  final file = File(filePath);
  final fileStream = file.openWrite();
  await fileStream.addStream(fileData.openRead());
  await fileStream.close();

  return Response(body: 'File uploaded successfully: $randomFileName');
}

Future<File> createSecretKey(String folderName, String secretKey) async {
  final directory = await Directory('uploads/$folderName').create(recursive: true);
  return File('${directory.path}/secretKey.txt').writeAsString(secretKey);
}

Future<bool> checkIsValidSecretKey(String folderName, String secretKey) async {
  final secretKeyFile = File('uploads/$folderName/secretKey.txt');
  if (!await secretKeyFile.exists()) return false;

  String storedKey = await secretKeyFile.readAsString();
  return storedKey == secretKey;
}

String generateRandomFileName(String folderName, String scriptKey, String extension) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final randomSuffix = base64Url.encode(List<int>.generate(6, (_) => Random().nextInt(256)))
      .replaceAll('=', ''); // Remove padding for a cleaner filename
  return '${folderName}_$scriptKey$timestamp$randomSuffix.$extension';

}
