import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method == HttpMethod.post) {
    return await _handleFileUpload(request);
  } else if (request.method == HttpMethod.get) {
    return await _handleGetFiles(request);
  } else if (request.method == HttpMethod.delete) {
    return await _handleDelete(request);
  } else {
    return Response.json(statusCode: 405, body: {'error': 'Method Not Allowed'});
  }
}

// Handle file uploads
Future<Response> _handleFileUpload(Request request) async {
  final formData = await request.formData();
  final fileData = formData.files['file'];
  final folderName = formData.fields['folderName'];
  final secretKey = formData.fields['secretKey'];

  if (fileData == null || folderName == null || secretKey == null) {
    return Response.json(statusCode: 400, body: {'error': 'Missing file, folderName, or secretKey'});
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
    return Response.json(statusCode: 400, body: {'error': 'Invalid secret key'});
  }

  // Ensure the uploads directory exists
  await Directory('uploads/$folderName').create(recursive: true);

  // Save the file to the server
  final file = File(filePath);
  final fileStream = file.openWrite();
  await fileStream.addStream(fileData.openRead());
  await fileStream.close();

  return Response.json(body: {'message': 'File uploaded successfully', 'fileName': randomFileName});
}

// Handle GET request to retrieve files
// Handle GET request to retrieve files
Future<Response> _handleGetFiles(Request request) async {
  final queryParams = request.uri.queryParameters;
  final folderName = queryParams['folderName'];
  final secretKey = queryParams['secretKey'];

  if (folderName == null || secretKey == null) {
    return Response.json(statusCode: 400, body: {'error': 'Missing folderName or secretKey'});
  }

  if (!await checkIsValidSecretKey(folderName, secretKey)) {
    return Response.json(statusCode: 403, body: {'error': 'Invalid secret key'});
  }

  final directory = Directory('uploads/$folderName');
  if (!await directory.exists()) {
    return Response.json(statusCode: 404, body: {'error': 'Folder not found'});
  }

  final baseUrl = 'https://file_host-b1c5-vsxzbhz-muhsin-p.globeapp.dev/uploads/$folderName';

  final files = directory.listSync()
      .whereType<File>()
      .where((file) => !file.path.endsWith('/secretKey.txt')) // Exclude secret key file
      .map((file) => {
    'fileName': file.uri.pathSegments.last,
    'url': '$baseUrl/${Uri.encodeComponent(file.uri.pathSegments.last)}'
  })
      .toList();

  return Response.json(body: {'files': files});
}


// Handle DELETE request (delete folder, file, or all folders)
Future<Response> _handleDelete(Request request) async {
  final queryParams = request.uri.queryParameters;
  final folderName = queryParams['folderName'];
  final fileName = queryParams['fileName'];
  final secretKey = queryParams['secretKey'];
  final deleteAll = queryParams['deleteAll'] == 'true';

  const masterSecretKey = 'MASTER_SECRET_123'; // Change this to your master key

  if (deleteAll) {
    // Only allow deleting all folders with master secret key
    if (secretKey != masterSecretKey) {
      return Response.json(statusCode: 403, body: {'error': 'Unauthorized master key'});
    }

    final uploadsDir = Directory('uploads');
    if (await uploadsDir.exists()) {
      await uploadsDir.delete(recursive: true);
      return Response.json(body: {'message': 'All folders deleted successfully'});
    } else {
      return Response.json(statusCode: 404, body: {'error': 'No folders found'});
    }
  }

  if (folderName == null || secretKey == null) {
    return Response.json(statusCode: 400, body: {'error': 'Missing folderName or secretKey'});
  }

  if (!await checkIsValidSecretKey(folderName, secretKey)) {
    return Response.json(statusCode: 403, body: {'error': 'Invalid secret key'});
  }

  if (fileName != null) {
    // Delete a specific file
    final file = File('uploads/$folderName/$fileName');
    if (await file.exists()) {
      await file.delete();
      return Response.json(body: {'message': 'File deleted successfully', 'fileName': fileName});
    } else {
      return Response.json(statusCode: 404, body: {'error': 'File not found'});
    }
  } else {
    // Delete the entire folder
    final folder = Directory('uploads/$folderName');
    if (await folder.exists()) {
      await folder.delete(recursive: true);
      return Response.json(body: {'message': 'Folder deleted successfully', 'folderName': folderName});
    } else {
      return Response.json(statusCode: 404, body: {'error': 'Folder not found'});
    }
  }
}

// Create secret key file
Future<File> createSecretKey(String folderName, String secretKey) async {
  final directory = await Directory('uploads/$folderName').create(recursive: true);
  return File('${directory.path}/secretKey.txt').writeAsString(secretKey);
}

// Validate secret key
Future<bool> checkIsValidSecretKey(String folderName, String secretKey) async {
  final secretKeyFile = File('uploads/$folderName/secretKey.txt');
  if (!await secretKeyFile.exists()) return false;

  String storedKey = await secretKeyFile.readAsString();
  return storedKey == secretKey;
}

// Generate unique file name
String generateRandomFileName(String folderName, String scriptKey, String extension) {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final randomSuffix = base64Url.encode(List<int>.generate(6, (_) => Random().nextInt(256)))
      .replaceAll('=', ''); // Remove padding for a cleaner filename
  return '${folderName}_$scriptKey$timestamp$randomSuffix.$extension';
}
