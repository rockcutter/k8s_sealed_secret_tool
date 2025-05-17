SSH := ssh
SCP := scp
KUBECTL := kubectl

SSH_TARGET := 
SECRET_NAME := 
SECRET_NAMESPACE := 

REMOTE_TMP_DIR := /tmp/k8s_sealed_secret_tool/secret

KUBESEAL_EXTRA_ARGS := 

.PHONY: help
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

.PHONY: scp
scp: require_ssh_target
	$(SSH) $(SSH_TARGET) "mkdir -p $(REMOTE_TMP_DIR)"
	$(SCP) ./.env $(SSH_TARGET):$(REMOTE_TMP_DIR)/tmp.env

.PHONY: fetch
secret: require_secret_name require_ssh_target
	$(SSH) $(SSH_TARGET) "$(KUBECTL) create secret generic $(SECRET_NAME) --from-env-file=$(REMOTE_TMP_DIR)/tmp.env --dry-run=client -o yaml > $(REMOTE_TMP_DIR)/secret.yaml"

seal: require_secret_name require_ssh_target require_secret_namespace
	$(SSH) $(SSH_TARGET) \
		"cat $(REMOTE_TMP_DIR)/secret.yaml | \
		kubeseal \
			$(KUBESEAL_EXTRA_ARGS) \
			--namespace $(SECRET_NAMESPACE) \
			--format yaml" \
		> sealed_secret.yaml

rm:
	$(SSH) $(SSH_TARGET) "rm -rf $(REMOTE_TMP_DIR)"
