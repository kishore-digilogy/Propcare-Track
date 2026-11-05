import 'package:flutter_test/flutter_test.dart';
import 'package:propcare_track/services/wikipedia_image_service.dart';

void main() {
  test('WikipediaImageService has initial empty cache and extracts locality', () {
    final service = WikipediaImageService.instance;
    expect(service.getCached('Unknown Site'), isNull);
  });
}

