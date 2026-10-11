# Мой гараж — GarageCare

Нативное iOS-приложение для локального учёта автомобилей, пробега, регламентных работ, истории обслуживания и заправок.

## Сборка

Проект генерируется через XcodeGen и проверяется в GitHub Actions на Xcode 27.

```bash
brew install xcodegen
xcodegen generate
xcodebuild build \
  -project GarageCare.xcodeproj \
  -scheme GarageCare \
  -configuration Debug \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO
```

Для CI не нужны сертификаты, provisioning profiles, API-ключи или другие секреты.

## Данные

Приложение local-first: основная база хранится на устройстве через SwiftData. Поддерживаются JSON backup/restore и CSV-экспорт истории.

## Privacy

Репозиторий не содержит signing credentials, provisioning profiles, API keys или пользовательских данных.
