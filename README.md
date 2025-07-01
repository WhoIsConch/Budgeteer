# Budgeteer

Budgeteer is an Android App built with Flutter that helps students manage their personal finances by tracking account balances, income, and expenses.

Budgeteer is built for FBLA's 2024/2025 Coding and Programming competitive event.

## Features

* **Transactions:** As the most important feature of the app, transactions allow users to track income and expenses. 
- **Accounts:** Represent an area where users store money, like a bank account.
- **Categories:** Allow users to sort transactions. Categories can be considered "budgets" and allow users to set a maximum spending limit in a certain period of time.
- **Goals:** Allow users to track progress towards a monetary goal, like saving up for something.

## Technologies Used
- **Framework:** Flutter
- **Language:** Dart
- **Backend/Database:** Supabase
- **Local Storage:** PowerSync with Drift

### Key Dart Packages Used \[pub.dev]

- dynamic_system_colors
- sqflite
- fl_chart
- auto_size_text
- flutter_colorpicker
- table_calendar
- drift
- sqlite_async
- drift_sqlite_async
- carousel_slider
- smooth_page_indicator

### Key Open-Source Tools Used

- [Microsoft Visual Studio Code](https//code.visualstudio.com)
- [Git](https://git-scm.com)

### Key Cloud Services Used

- [Supabase](https://supabase.com)
- [PowerSync](https://powersync.com)
- Google Cloud (for Google log in)

## Installation

### From APK / AAB

To install a pre-built version of Budgeteer, view this repository's [releases](https://github.com/WhoIsConch/Budgeteer/releases/) page, and use Google's [bundletool](https://github.com/google/bundletool) to install the .apks file to your device.

### Building / Development

To build Budgeteer, ensure you have Flutter and Dart installed. Flutter also requires a PowerSync instance and Supabase instance. Please refer to the `.env.example` for putting in variable cloud keys and URLs.

Once Flutter's packages are installed, it can be run by using Flutter's common build command:

```
flutter run
```
