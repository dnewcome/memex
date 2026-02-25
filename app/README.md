# memex (Flutter)

Flutter frontend for the Memex note-taking app. Talks to the local Fastify API at `http://localhost:3000`.

## Requirements

- Flutter SDK (stable channel)
- The API running locally (`cd ../api && npm run dev`)

## Running

```bash
flutter pub get
flutter run
```

Pick a target device when prompted, or specify one:

```bash
flutter run -d macos
flutter run -d chrome
```

## Structure

```
lib/
├── main.dart                       # App entry point, go_router config, MaterialApp
├── api/
│   └── api_client.dart             # Dio HTTP client — base URL configured here
├── models/
│   ├── block.dart
│   ├── entity.dart
│   └── observation.dart            # Includes PendingObservation with contextMessage
├── providers/
│   ├── api_provider.dart           # Singleton ApiClient
│   ├── blocks_provider.dart        # AsyncNotifier for block list + detail
│   ├── entities_provider.dart      # FutureProvider for entity list + detail
│   └── observations_provider.dart  # StateProvider for in-memory pending observations
└── screens/
    ├── home_screen.dart            # Block list, create/delete
    ├── editor_screen.dart          # Editor with pending observation banner
    └── entity_screen.dart          # Entity list and observation timeline
```

## Connecting to a non-localhost API

Update `_baseUrl` in `lib/api/api_client.dart`:

```dart
static const String _baseUrl = 'http://192.168.1.x:3000/api/v1';
```

This is needed when running on a physical device or Android emulator that can't reach `localhost` directly.
