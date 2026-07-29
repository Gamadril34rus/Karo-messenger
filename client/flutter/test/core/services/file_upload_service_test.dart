import 'package:flutter_test/flutter_test.dart';
import 'package:charo_messenger/core/services/file_upload_service.dart';

void main() {
  group('FileUploadService', () {
    test('maxFileSize is 100 MB', () {
      expect(FileUploadService.maxFileSize, 100 * 1024 * 1024);
    });

    test('UploadedFileResult creates with all fields', () {
      const result = UploadedFileResult(
        url: 'https://cdn.charo.chat/uploads/test.jpg',
        thumbnailUrl: 'https://cdn.charo.chat/thumbnails/test.jpg',
        type: 'image',
        fileName: 'test.jpg',
        fileSize: 1024,
      );

      expect(result.url, 'https://cdn.charo.chat/uploads/test.jpg');
      expect(result.thumbnailUrl, 'https://cdn.charo.chat/thumbnails/test.jpg');
      expect(result.type, 'image');
      expect(result.fileName, 'test.jpg');
      expect(result.fileSize, 1024);
    });

    test('UploadedFileResult defaults thumbnailUrl to empty', () {
      const result = UploadedFileResult(
        url: 'https://cdn.charo.chat/uploads/test.pdf',
        type: 'file',
        fileName: 'test.pdf',
        fileSize: 2048,
      );

      expect(result.thumbnailUrl, '');
    });
  });
}
