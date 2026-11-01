# LiveWall — живые обои для iPhone

Приложение на SwiftUI, которое делает **Live Photo** из обычного видео или фотографии.
Дальше Live Photo ставится как обои на экран блокировки (анимация при пробуждении/нажатии).

> Важно: iOS не даёт приложениям менять обои программно. Приложение создаёт и сохраняет
> Live Photo в «Фото», а установка занимает 5 шагов в системных настройках (инструкция внутри приложения).

## Что умеет

- Импорт видео из «Фото» (MP4/MOV) и обрезка фрагмента 1–5 секунд.
- Импорт фото (JPG/HEIC) и превращение его в «живое» с эффектом Кена Бёрнса (плавный зум).
- Подгонка кадра под экран iPhone: «Заполнить» (crop) или «Вписать» (letterbox).
- Сборка настоящего Live Photo: JPEG со ссылкой `MakerApple 17` + MOV с
  `com.apple.quicktime.content.identifier` и тайм-метаданными `still-image-time`.
- Сохранение сразу в Фотопленку через `PHAssetCreationRequest` (photo + pairedVideo).
- Встроенная инструкция по установке обоев на русском.

## Структура

```
LiveWall/
├── LiveWall.xcodeproj/          # проект Xcode (iOS 17+, SwiftUI)
├── LiveWall/
│   ├── LiveWallApp.swift        # точка входа
│   ├── ContentView.swift        # таб-бар
│   ├── CreateView.swift         # экран создания
│   ├── GuideView.swift          # инструкция
│   ├── StudioModel.swift        # состояние и экспорт
│   ├── MediaPicker.swift        # Transferable для PhotosPicker
│   ├── LivePhotoMaker.swift     # сборка Live Photo (видео и фото)
│   ├── MovieWriter.swift        # AVAssetWriter + метаданные Live Photo
│   ├── VideoPreview.swift       # зацикленное превью фрагмента
│   ├── Theme.swift              # оформление
│   ├── Info.plist
│   └── Assets.xcassets          # иконка и акцентный цвет
├── tools/make-icon.ps1          # генерация иконки (Windows/PowerShell)
└── .github/workflows/build-ipa.yml
```

## Сборка в Xcode (нужен Mac)

1. Откройте `LiveWall.xcodeproj`.
2. Выберите свою команду в **Signing & Capabilities** (или личный Apple ID:
   Xcode → Settings → Accounts → Add Apple ID).
3. Подключите iPhone и нажмите **Run** (⌘R).
   Бесплатный аккаунт: приложение живёт 7 дней, потом переподписать.
4. Для установки без Mac можно собрать `.ipa` и подписать его на Windows через
   Sideloadly / AltStore (см. ниже).

## Как получить .ipa без Mac

Вариант 1 — GitHub Actions (бесплатно, без Mac):

1. Залейте папку `LiveWall` в репозиторий GitHub.
2. Вкладка **Actions** → **Build IPA** → **Run workflow**.
3. Через пару минут скачайте артефакт `LiveWall-unsigned-ipa` (`LiveWall.ipa`).
4. Подпишите его своим Apple ID через [Sideloadly](https://sideloadly.io) на Windows:
   - подключите iPhone, откройте Sideloadly;
   - перетащите `LiveWall.ipa`, введите Apple ID;
   - нажмите Start и доверьте профилю в Настройки → Основные → VPN и управление устройством.

Вариант 2 — локально на Mac:

```bash
xcodebuild -project LiveWall.xcodeproj -scheme LiveWall -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/LiveWall.xcarchive archive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

mkdir -p build/Payload
cp -R build/LiveWall.xcarchive/Products/Applications/LiveWall.app build/Payload/
cd build && zip -qry LiveWall.ipa Payload
```

## Как поставить обои

1. Создайте Live Photo в приложении.
2. Настройки → Обои → «Добавить новые обои» → «Фото».
3. Выберите свежее фото со значком **LIVE**.
4. Включите кнопку **Live Photo** внизу экрана.
5. «Добавить» → «Установить как пару обоев».

Если анимации нет — отключите «Универсальный доступ → Движение → Уменьшение движения».

## Ограничения

- Звук из видео не переносится (для обоев он не нужен).
- Длина Live Photo ограничена 5 секундами.
- iPhone 6s и новее; iOS 17+.
- Приложение не публикуется в App Store (нет прав на «обои»), ставится через sideload.

## Лицензия

MIT — делайте что хотите.
