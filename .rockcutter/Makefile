MAKE := make \
	SSH_TARGET=orion_no_bashrc \
	SCP=scp.exe \
	SSH=ssh.exe \
	KUBECTL="microk8s kubectl" \
	KUBESEAL_EXTRA_ARGS="--controller-namespace=sealed-secrets --controller-name=sealed-secrets"

run: 
	$(MAKE) -C .. $(ARGS)

example: 
	make run \
		ARGS="all" \
		SECRET_NAME=test_secret \
		SECRET_NAMESPACE=test_secret_namespace
