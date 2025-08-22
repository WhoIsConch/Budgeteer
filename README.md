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

### Devcontainer Information

This project utilizes Dev Containers. 

The Dev Container configuration for this project is modified from [wtfzambo's flutter-devcontainer-template](https://github.com/wtfzambo/flutter-devcontainer-template). To accomodate the support of physical devices, the Dev Container uses the network of its host by passing `--network host` into `runArgs` of `devcontainer.json`. If WSL is being used, WSL should be in mirrored networking mode. This will allow the container's ADB instance to connect to the Windows ADB server instead of spinning up its own. 

#### 1. Make Host ADB Server Listen on All Network Interfaces

On the host device (e.g. Windows when using WSL), kill the ADB server instance:

```
adb kill-server
```

Then, start a new instance, ensuring you pass the -a flag to make the ADB server listen on all network interfaces:

```
adb -a start-server
```

#### 2. (WSL) Ensure WSL is in Mirrored Networking Mode

Mirrored Networking Mode makes the WSL instance share the same networking information as the host machine. WSL's networking mode can be changed in WSL Settings by selecting Networking > Networking Mode > Mirrored. Also ensure Hyper-V Firewall allows inbound connections so the adb client in WSL can connect to the host's ADB server. 

For more information, visit [Microsoft's WSL Networking docs](https://learn.microsoft.com/en-us/windows/wsl/networking#mirrored-mode-networking).

#### 3. Build the Container

With these couple of settings in place, the container's ADB client should be able to connect to the host's ADB server. If you are running the container manually, ensure `--network=host` is passed into docker's arguments so the container uses the network of the host device. This setting is included in `devcontainer.json`.



