# aws-demo-infra

このリポジトリは AWS 上に以下のリソースを作成するためのサンプルです（CloudFormation を推奨）。

- ネットワーク (VPC, サブネット, IGW, ルート)
- アプリケーションロードバランサー (ALB)
- Amazon ECS (Fargate) クラスタ、タスク、サービス
- Amazon DynamoDB テーブル

構成:

- `common/` : サービス単位の CloudFormation テンプレートを配置（`network.yaml`, `alb.yaml`, `ecs.yaml`, `dynamodb.yaml`）。
- `<env>/params.yaml` : 環境ごとのパラメータを定義（`dev`, `staging`, `prod`）。YAML ファイルを必須とします。
- `deploy.sh` : パッケージングとデプロイを行うスクリプト（`S3_BUCKET` 環境変数が必要、`ENV` 環境変数で環境選択）。

クイックデプロイ手順（例: dev 環境）:

```bash
cd aws-demo-infra
export S3_BUCKET=your-deployment-bucket
ENV=dev ./environments/deploy.sh
```

注記:

- `aws` CLI と `yq` が必要です。
