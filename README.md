# LAN Transfer

局域网跨平台文本/文件传输工具，支持 iOS / Android / macOS / Windows。

## 快速开始

```bash
# 1. 进入项目目录
cd lan_transfer

# 2. 安装依赖
flutter pub get

# 3. 运行
flutter run                     # 当前连接的设备
flutter run -d windows          # Windows
flutter run -d macos            # macOS
flutter run -d android          # Android
flutter run -d ios              # iOS
```

## 构建发布包

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release
```

## 项目结构

```
lib/
├── main.dart
├── core/
│   ├── models/         # DeviceInfo, ReceivedItem
│   ├── server/         # HTTP 服务端 (shelf)
│   ├── client/         # HTTP 客户端 (dio)
│   ├── discovery/      # mDNS 自动发现 (bonsoir)
│   └── utils/          # 网络工具
├── providers/          # 全局状态 (ChangeNotifier)
└── screens/            # 所有页面
    ├── home_screen.dart
    ├── send_screen.dart
    ├── received_items_screen.dart
    ├── qr_display_screen.dart      # 显示二维码
    ├── qr_scan_screen.dart         # 扫描二维码 (iOS/Android)
    └── manual_connect_screen.dart  # 手动输入 IP
```

## 协议

```
端口: 53317

GET  /ping             → 返回设备信息 JSON
POST /receive/text     → 接收文本 (JSON body: {"text": "..."})
POST /receive/file     → 接收文件 (octet-stream body + x-file-name header)
```

## 已知限制

- iOS 后台时 HTTP 服务器会停止（iOS 系统限制）
- Windows 首次运行需要在防火墙中允许 53317 端口
- mDNS 自动发现需要设备在同一子网且路由器不屏蔽多播
