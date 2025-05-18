SSH := ssh
SCP := scp
KUBECTL := kubectl

SSH_TARGET := 
SECRET_NAME := 
SECRET_NAMESPACE := 

REMOTE_TMP_DIR := /tmp/k8s_sealed_secret_tool/secret

KUBESEAL_EXTRA_ARGS := 

.PHONY: help all require_ssh_target require_secret_name require_secret_namespace scp scp/env scp/secret secret seal fetch_secret decode_secret encode_secret rm
help:
	less Makefile

all: scp secret seal rm

require_ssh_target:
ifeq ($(SSH_TARGET),)
	$(error SSH_TARGET is not set)
endif

require_secret_name: 
ifeq ($(SECRET_NAME),)
	$(error SECRET_NAME is not set)
endif

require_secret_namespace: 
ifeq ($(SECRET_NAMESPACE),)
	$(error SECRET_NAMESPACE is not set)
endif

scp/env: require_ssh_target
	$(SSH) $(SSH_TARGET) "mkdir -p $(REMOTE_TMP_DIR)"
	$(SCP) ./env $(SSH_TARGET):$(REMOTE_TMP_DIR)/tmp.env

scp/secret: require_ssh_target
	$(SSH) $(SSH_TARGET) "mkdir -p $(REMOTE_TMP_DIR)"
	$(SCP) ./secret.json $(SSH_TARGET):$(REMOTE_TMP_DIR)/secret.json

secret: require_secret_name require_ssh_target
	$(SSH) $(SSH_TARGET) "$(KUBECTL) create secret generic $(SECRET_NAME) --from-env-file=$(REMOTE_TMP_DIR)/tmp.env --dry-run=client -o json > $(REMOTE_TMP_DIR)/secret.json"

seal: require_ssh_target require_secret_namespace
	$(SSH) $(SSH_TARGET) \
		"cat $(REMOTE_TMP_DIR)/secret.json | \
		kubeseal \
			$(KUBESEAL_EXTRA_ARGS) \
			--namespace $(SECRET_NAMESPACE) \
			--format yaml" \
		> sealed_secret.yaml

fetch_secret: require_secret_name require_ssh_target require_secret_namespace
	$(SSH) $(SSH_TARGET) \
		"$(KUBECTL) get secret $(SECRET_NAME) \
			-n $(SECRET_NAMESPACE) \
			-o json" \
		> secret.json 
		| jq ' .data |= with_entries(.value |= @base64d)' > secret_base64d.json

decode_secret: 
	cat secret.json \
		| jq ' .data |= with_entries(.value |= @base64d)' > secret_base64d.json

encode_secret: 
	cat secret_base64d.json \
		| jq ' .data |= with_entries(.value |= @base64)' > secret.json

rm:
	$(SSH) $(SSH_TARGET) "rm -rf $(REMOTE_TMP_DIR)"
