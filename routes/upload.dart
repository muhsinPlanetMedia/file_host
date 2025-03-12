import 'dart:io';

import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method != HttpMethod.post) {
    return Response(statusCode: 405, body: 'Method Not Allowed');
  }

  final formData = await request.formData();
  final fileData = formData.files['file'];



  if (fileData == null) {
    return Response(statusCode: 400, body: 'No file uploaded');
  }

  final fileName = fileData.name ?? 'unknown_file';
  final filePath = 'uploads/$fileName';

  // Create the uploads directory if it doesn't exist
  await Directory('uploads').create(recursive: true);

  // Save the file to the server
  final file = File(filePath);
  final fileStream = file.openWrite();
  await fileStream.addStream(fileData.openRead());
  await fileStream.close();

  return Response(body: 'File uploaded successfully:');
}
