import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

Handler middleware(Handler handler) {
  return (context) async {
    final request = context.request;

    // Check if the request is for a static file inside the "uploads" directory
    if (request.uri.path.startsWith('uploads/')) {
      final filePath = request.uri.path;
      final file = File(filePath);

      if (await file.exists()) {
        final fileBytes = await file.readAsBytes(); // Read file as bytes

        return Response.bytes(
          body: fileBytes,
          headers: {
            HttpHeaders.contentTypeHeader: _getContentType(filePath),
          },
        );
      }

      return Response(statusCode: 404, body: 'File not found');
    }

    return handler(context);
  };
}

// Function to determine correct Content-Type
String _getContentType(String filePath) {
  final extension = filePath.split('.').last;
  switch (extension) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'pdf':
      return 'application/pdf';
    default:
      return 'application/octet-stream';
  }
}
