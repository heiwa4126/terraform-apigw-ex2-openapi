# terraform-apigw-ex1

TerraformでAWS Lambda (Python) & API Gateway のサンプル。

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


# TIPS: integration_http_method

[integration_http_method](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_integration#integration_http_method) は typeがAWS* なら、必ず"POST"。

参照:  [Lambda 統合を使用した API Gateway API の「Execution failed due to configuration」(設定エラーのため実行に失敗しました) エラーを修正する](https://aws.amazon.com/jp/premiumsupport/knowledge-center/api-gateway-lambda-template-invoke-error/)


# TIPS: aws_api_gateway_deployment

API Gatewayの構造を変えたときに、aws_api_gateway_deploymentを更新しないと変更が反映されない。

いくつか方法はあるけど(OpenAPIにしてgw.bodyのハッシュ比較をトリガにするのがよさそう)、
ここでは `taint_deployment.sh` を手動で呼ぶことにした。
