# Frontend Cloud Run Module

このモジュールは、同じFlutterアプリケーションを異なるデプロイメント戦略でデプロイします。

## デプロイメント戦略

### Strategy 1: Direct Backend Access (`direct-backend-access`)

**概要**: ブラウザから直接バックエンドAPIを呼び出す

**特徴**:
- Nginxは静的ファイル配信のみ(ポート8080)
- ブラウザがバックエンドに直接HTTPリクエストを送信
- バックエンドは公開アクセス可能である必要がある(`INGRESS_TRAFFIC_ALL`)
- CORSをバックエンド側で設定する必要がある
- シンプルな構成

**使用ケース**:
- 開発環境
- バックエンドが公開されても問題ない場合
- シンプルな構成を優先する場合

**Dockerイメージ**: `frontend-static` (frontend-static/Dockerfile)

### Strategy 2: Reverse Proxy (`reverse-proxy`)

**概要**: Nginxがバックエンドへのリクエストをプロキシ

**特徴**:
- Nginxがリバースプロキシとして動作(ポート80)
- フロントエンドから`/api/*`への同一オリジンリクエスト
- Nginxがバックエンド(内部URL)にプロキシ
- バックエンドを内部専用にできる(`INGRESS_TRAFFIC_INTERNAL_ONLY`)
- CORS問題なし(同一オリジンリクエスト)
- より安全な構成

**使用ケース**:
- 本番環境
- バックエンドを内部専用にしたい場合
- セキュリティを優先する場合

**Dockerイメージ**: `frontend` (frontend/Dockerfile)

## 使用例

```hcl
module "frontend_static" {
  source = "./modules/frontend"

  service_name        = "my-frontend-static"
  region              = "asia-northeast1"
  image_url           = "gcr.io/my-project/frontend-static:latest"
  deployment_strategy = "direct-backend-access"
  container_port      = 8080

  resources = {
    cpu    = "1"
    memory = "512Mi"
  }

  scaling = {
    min_instance_count = 0
    max_instance_count = 10
  }

  vpc = {
    network    = "my-network"
    subnetwork = "my-subnet"
  }
}

module "frontend_proxy" {
  source = "./modules/frontend"

  service_name        = "my-frontend-proxy"
  region              = "asia-northeast1"
  image_url           = "gcr.io/my-project/frontend:latest"
  deployment_strategy = "reverse-proxy"
  container_port      = 80
  backend_url         = "https://backend-xyz.run.app"

  resources = {
    cpu    = "1"
    memory = "512Mi"
  }

  scaling = {
    min_instance_count = 0
    max_instance_count = 10
  }

  vpc = {
    network    = "my-network"
    subnetwork = "my-subnet"
  }

  depends_on_services = [google_cloud_run_v2_service.backend]
}
```

## 入力変数

| 変数名 | 説明 | 必須 |
|--------|------|------|
| `service_name` | Cloud Runサービス名 | ✓ |
| `region` | GCPリージョン | ✓ |
| `image_url` | DockerイメージURL | ✓ |
| `deployment_strategy` | デプロイメント戦略 (`direct-backend-access` または `reverse-proxy`) | ✓ |
| `container_port` | コンテナポート (static: 8080, proxy: 80) | ✓ |
| `backend_url` | バックエンドURL (reverse-proxy戦略で必須) | △ |
| `resources` | リソース制限 | ✓ |
| `scaling` | オートスケール設定 | ✓ |
| `vpc` | VPC設定 | ✓ |
| `ingress` | Ingress設定 | - |
| `depends_on_services` | 依存サービスリスト | - |

## 出力

| 変数名 | 説明 |
|--------|------|
| `service_url` | Cloud RunサービスURL |
| `service_name` | Cloud Runサービス名 |
| `deployment_strategy` | 使用されたデプロイメント戦略 |
