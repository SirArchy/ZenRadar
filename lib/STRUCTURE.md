# ZenRadar lib Structure

This project now has a clearer, layered folder structure:

- `presentation/screens/`: screen entry points grouped by feature
- `presentation/widgets/`: reusable widgets grouped by type
- `data/services/`: services grouped by responsibility

## Phase 3 Status

Phase 3 is complete.

- Implementation files are organized under `presentation/` and `data/services/`.
- Legacy wrapper files under `screens/`, `widgets/`, and `services/` have been removed.
- Imports are normalized to the new package paths.

## Suggested Import Style

Prefer these imports for new code:

```dart
import 'package:zenradar/presentation/screens/screens.dart';
import 'package:zenradar/presentation/widgets/widgets.dart';
import 'package:zenradar/data/services/services.dart';
```

For more explicit imports, use the feature path directly, for example:

```dart
import 'package:zenradar/presentation/screens/home/home_screen_content.dart';
import 'package:zenradar/data/services/notifications/notification_service.dart';
```
