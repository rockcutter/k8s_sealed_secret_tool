# Kubernetes Sealed Secret ツール
# このMakefileはKubernetesのSealed Secretsを作成・管理するためのツールです

# 基本コマンド定義
SSH := ssh
SCP := scp
KUBECTL := kubectl

# 設定変数
SSH_TARGET :=  # SSHでの接続先（例: user@hostname）
SECRET_NAME :=  # 作成するSecretの名前
SECRET_NAMESPACE :=  # Secretを配置するNamespace

# リモートサーバー上の一時ディレクトリ
REMOTE_TMP_DIR := /tmp/k8s_sealed_secret_tool/secret

# kubesealコマンドの追加引数
KUBESEAL_EXTRA_ARGS := 

# ターゲット定義
.PHONY: help all require_ssh_target require_secret_name require_secret_namespace scp scp/env scp/secret secret seal fetch_secret decode_secret encode_secret rm

# Makefileの使い方を表示
help:
	less Makefile

# 全プロセスを実行（環境変数転送、Secret作成、Seal処理、一時ファイル削除）
all: scp/env secret seal rm

# SSH_TARGETが設定されているか確認
require_ssh_target:
ifeq ($(SSH_TARGET),)
	$(error SSH_TARGET is not set)
endif

# SECRET_NAMEが設定されているか確認
require_secret_name: 
ifeq ($(SECRET_NAME),)
	$(error SECRET_NAME is not set)
endif

# SECRET_NAMESPACEが設定されているか確認
require_secret_namespace: 
ifeq ($(SECRET_NAMESPACE),)
	$(error SECRET_NAMESPACE is not set)
endif

# 環境変数ファイルをリモートサーバーに転送
scp/env: require_ssh_target
	$(SSH) $(SSH_TARGET) "mkdir -p $(REMOTE_TMP_DIR)"
	$(SCP) ./env $(SSH_TARGET):$(REMOTE_TMP_DIR)/tmp.env

# Secretファイルをリモートサーバーに転送
scp/secret: require_ssh_target
	$(SSH) $(SSH_TARGET) "mkdir -p $(REMOTE_TMP_DIR)"
	$(SCP) ./secret.json $(SSH_TARGET):$(REMOTE_TMP_DIR)/secret.json

# 環境変数ファイルからSecretを作成
secret: require_secret_name require_ssh_target
	$(SSH) $(SSH_TARGET) "$(KUBECTL) create secret generic $(SECRET_NAME) --from-env-file=$(REMOTE_TMP_DIR)/tmp.env --dry-run=client -o json > $(REMOTE_TMP_DIR)/secret.json"

# Secretをシールしてsealed_secret.yamlを作成
seal: require_ssh_target require_secret_namespace
	$(SSH) $(SSH_TARGET) \
		"cat $(REMOTE_TMP_DIR)/secret.json | \
		kubeseal \
			--scope namespace-wide \
			$(KUBESEAL_EXTRA_ARGS) \
			--namespace $(SECRET_NAMESPACE) \
			--format yaml" \
		> sealed_secret.yaml

# 既存のSecretをクラスターから取得
fetch_secret: require_secret_name require_ssh_target require_secret_namespace
	$(SSH) $(SSH_TARGET) \
		"$(KUBECTL) get secret $(SECRET_NAME) \
			-n $(SECRET_NAMESPACE) \
			-o json" \
		> secret.json 

# Secretのデータをbase64デコード
decode_secret: 
	cat secret.json \
		| jq ' .data |= with_entries(.value |= @base64d)' > secret_base64d.json

# デコードされたSecretをbase64エンコード
encode_secret: 
	cat secret_base64d.json \
		| jq ' .data |= with_entries(.value |= @base64)' > secret.json

# decode 済み secret.json を env ファイルに変換
env_from_secret: 
	cat secret_base64d.json \
		| jq -r '.data | to_entries | map("\(.key)=\(.value)") | .[]' > env

# リモートサーバー上の一時ファイルを削除
rm:
	$(SSH) $(SSH_TARGET) "rm -rf $(REMOTE_TMP_DIR)"