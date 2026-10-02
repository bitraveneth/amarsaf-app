# AmarSaf Field

Phone companion for [AmarSaf ERP](https://erp.amarsaf.com). One Flutter app for Android and iPhone. Sales staff punch in, log dealer visits, claim TA/DA with a bill photo, and place an order for a dealer in their zone. Dealers and distributors browse finished goods, place orders, and read dues.

The phone never talks to MySQL. It signs in with Laravel Sanctum (`POST /api/login`) and every save goes through the ERP API. The server stays the source of truth. If the network drops, punch, visit, bill, and order are kept on the phone and sent on the next sync.

Driver screens are not in this app.

## Run

Install [Flutter](https://docs.flutter.dev/get-started/install) (stable), then:

```bash
flutter pub get
flutter run
```

Use a device or emulator. Location and camera are used for punch, shift pings, visit completion, and bill photos.

Default API: `https://erp.amarsaf.com` (`/api` is added for you). On the sign-in screen you can point the app at another ERP, including `http://` on a local network.

English and Bengali switch from the top bar.

## What is on the phone

**Sales (employee login)**

- Home: today's attendance, this month's TA and DA, open visits, target achieved from delivered orders
- Punch in and punch out with GPS
- While punched in and the app is open, a location ping about every 12 minutes (`POST /api/employee/location-logs`). Punch out stops it. The app does not track in the background.
- Today's visits: list, add, mark visited (GPS saved when you complete with location)
- TA/DA amount plus a bill photo
- Order for a dealer in the employee's zone

**Dealer (agent login)**

- Finished-goods price list, search, and paging
- Place an order (`regular`, `bulk`, `sample`, `return`)
- My orders
- Dues and statement

## Checks

```bash
flutter analyze
flutter test
```
