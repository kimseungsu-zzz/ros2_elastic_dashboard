import 'package:http/http.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:material_ui/material_ui.dart';

import 'package:elastic_dashboard/services/update_checker.dart';

import 'test_util.mocks.dart';

@GenerateNiceMocks([MockSpec<UpdateChecker>()])
MockUpdateChecker createMockUpdateChecker({
  bool updateAvailable = false,
  String latestVersion = '0.0.0.0',
}) {
  MockUpdateChecker updateChecker = MockUpdateChecker();

  when(updateChecker.isUpdateAvailable()).thenAnswer(
    (_) => Future.value(
      UpdateCheckerResponse(
        updateAvailable: updateAvailable,
        error: false,
        latestVersion: latestVersion,
      ),
    ),
  );

  return updateChecker;
}

@GenerateNiceMocks([MockSpec<Client>()])
MockClient createHttpClient({Map<String, Response>? mockGetResponses}) {
  MockClient mockClient = MockClient();

  if (mockGetResponses != null) {
    for (MapEntry<String, Response> mockRequest in mockGetResponses.entries) {
      when(
        mockClient.get(Uri.parse(mockRequest.key)),
      ).thenAnswer((_) => Future.value(mockRequest.value));
    }
  }
  return mockClient;
}

void ignoreOverflowErrors(
  FlutterErrorDetails details, {
  bool forceReport = false,
}) {
  // ---

  bool ifIsOverflowError = false;
  bool isUnableToLoadAsset = false;

  // Detect overflow error.
  var exception = details.exception;
  if (exception is FlutterError) {
    ifIsOverflowError = !exception.diagnostics.any(
      (e) => e.value.toString().startsWith('A RenderFlex overflowed by'),
    );
    isUnableToLoadAsset = !exception.diagnostics.any(
      (e) => e.value.toString().startsWith('Unable to load asset'),
    );
  }

  // Ignore if is overflow error.
  if (ifIsOverflowError || isUnableToLoadAsset) {
    return;
  } else {
    FlutterError.dumpErrorToConsole(details, forceReport: forceReport);
    // exit(1);
  }
}
