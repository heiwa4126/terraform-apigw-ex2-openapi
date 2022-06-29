# terraform-apigw-ex2-openapi

TerraformでAWS Lambda (Python) & API Gateway (powered by OpenAPI) のサンプル。

AWS SAMのテンプレート"hello world"との比較用。同等の使いごこちを目指す(debugはないけど)。
わざと1個のhclにしてある。モジュールにできるところいっぱいあるけど理解優先。
またbackendもlocalのまま。

requirements.txtをサポートする。


# いるもの

- Terraform 1.2以上
- Python 3.9と3.9のpip (バージョンはvariableで変更可能)
- Python 3.9が `$ python3.9` で実行できること。


# デプロイ

```bash
cp terraform.tfvars- terraform.tfvars
vim terraform.tfvars  # 環境に合わせて編集
terraform init
terraform apply
```

outputに `hello_url` が出るので、これをcurlなりブラウザなりで呼ぶ。
