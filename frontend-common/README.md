# Frontend Common Application

このディレクトリには、すべてのフロントエンドデプロイメントで共通のFlutter Webアプリケーションコードが含まれています。

## 概要

このアプリケーションは、異なるデプロイメント戦略で複数回デプロイされます：

- **frontend-proxy/** - Strategy 2: Reverse Proxy
- **frontend-static/** - Strategy 1: Direct Backend Access

**重要**: これらのディレクトリは、このディレクトリへのシンボリックリンクを使用しています。
アプリケーションコードの変更は、**このディレクトリで**行ってください。

## ディレクトリ構成

```
frontend-common/
├── lib/                   # Dartアプリケーションコード
│   └── main.dart         # アプリケーションエントリーポイント
├── web/                   # Web固有のファイル
│   ├── index.html        # HTMLエントリーポイント
│   ├── favicon.png
│   └── manifest.json
├── test/                  # ユニットテスト
├── pubspec.yaml          # Flutter依存関係
├── pubspec.lock          # ロックファイル
└── analysis_options.yaml # Dart分析設定
```

## シンボリックリンク構成

各デプロイメントディレクトリは、以下のファイル/ディレクトリに対してシンボリックリンクを使用しています：

```bash
frontend-proxy/lib -> ../frontend-common/lib
frontend-proxy/web -> ../frontend-common/web
frontend-proxy/test -> ../frontend-common/test
frontend-proxy/pubspec.yaml -> ../frontend-common/pubspec.yaml
frontend-proxy/pubspec.lock -> ../frontend-common/pubspec.lock
frontend-proxy/analysis_options.yaml -> ../frontend-common/analysis_options.yaml

# frontend-staticも同様
```

## 開発方法

### 依存関係のインストール

```bash
cd frontend-common
flutter pub get
```

### 開発サーバーの起動

```bash
cd frontend-common
flutter run -d chrome
```

### テストの実行

```bash
cd frontend-common
flutter test
```

### ビルド

ビルドは、各デプロイメントディレクトリのDockerfileで行われます：

- `frontend-proxy/Dockerfile` - リバースプロキシ構成でビルド
- `frontend-static/Dockerfile` - 静的ファイル配信構成でビルド

## 注意事項

1. **アプリケーションコードの変更**: このディレクトリで行ってください
2. **デプロイメント固有の設定**: 各デプロイメントディレクトリ（`frontend-proxy/`、`frontend-static/`）で行ってください
3. **シンボリックリンクの扱い**: Git はシンボリックリンクを追跡しますが、実際のファイルはこのディレクトリにのみ存在します

## アーキテクチャ

このアプリケーションは、バックエンドAPIと通信するシンプルなFlutter Webアプリです。

- バックエンドとの通信方法は、デプロイメント戦略によって異なります
- Strategy 1 (frontend-static): ブラウザから直接バックエンドへHTTPSリクエスト
- Strategy 2 (frontend): 同一オリジン `/api/*` へのリクエスト（Nginxがプロキシ）

詳細は [FRONTEND_CONFIGURATIONS.md](../FRONTEND_CONFIGURATIONS.md) を参照してください。
