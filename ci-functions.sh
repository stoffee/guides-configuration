# This script includes a set of generic CI functions to test Packer Builds.
prepare () {
  rm -rf /tmp/packer
  curl -o /tmp/packer.zip https://releases.hashicorp.com/packer/${PACKER_VERSION}/packer_${PACKER_VERSION}_linux_amd64.zip
  unzip /tmp/packer.zip -d /tmp
  chmod +x /tmp/packer
}

validate () {
  for PRODUCT in $*; do
    echo "Reviewing ${PRODUCT} template ...             "
    cd "${BUILDDIR}/${PRODUCT}"
    if /tmp/packer validate *.json > /dev/null; then
      echo -e "\033[32m\033[1m[PASS]\033[0m"
    else
      echo -e "\033[31m\033[1m[FAIL]\033[0m"
      return 1
    fi
    cd -
  done
  echo "Reviewing shell scripts ..."
  if find . -iname \*.sh -exec bash -n {} \; > /dev/null; then
    echo -e "\033[32m\033[1m[PASS]\033[0m"
  else
    echo -e "\033[31m\033[1m[FAIL]\033[0m"
    return 1
  fi
}

build () {
  export CONSUL_RELEASE="${CONSUL_VERSION}"
  export VAULT_RELEASE="${VAULT_VERSION}"
  for PRODUCT in $*; do
    echo "Building ${PRODUCT} template ...             "
    cd "${BUILDDIR}/${PRODUCT}"
    if /tmp/packer build *.json ; then
      echo -e "\033[32m${PRODUCT} \033[1m[PASS]\033[0m"
    else
      echo -e "\033[31m${PRODUCT} \033[1m[FAIL]\033[0m"
      return 1
    fi
    cd -
  done
}

build_ent () {
  echo ${PGP_SECRET_KEY} | base64 -d | gpg --import
  export CONSUL_ENT_URL=$(AWS_SECRET_ACCESS_KEY=$(echo $AWS_SECRET_ACCESS_KEY_BINARY | base64 -d | gpg -d -) AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID_BINARY} aws s3 presign --region="us-east-1" s3://${S3BUCKET}/consul-enterprise/${CONSUL_VERSION}/consul-enterprise_${CONSUL_VERSION}+ent_linux_amd64.zip --expires-in 600)
  export VAULT_ENT_URL=$(AWS_SECRET_ACCESS_KEY=$(echo $AWS_SECRET_ACCESS_KEY_BINARY | base64 -d | gpg -d -) AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID_BINARY} aws s3 presign --region="us-east-1" s3://${S3BUCKET}/vault-enterprise/${VAULT_VERSION}/vault-enterprise_${VAULT_VERSION}_linux_amd64.zip --expires-in 600)
  export CONSUL_RELEASE="${CONSUL_VERSION}"
  export VAULT_RELEASE="${VAULT_VERSION}"
  export CONSUL_VERSION="${CONSUL_VERSION}+ent"
  export VAULT_VERSION="${VAULT_VERSION}+ent"
  for PRODUCT in $*; do
    echo "Building ${PRODUCT} template ...             "
    cd "${BUILDDIR}/${PRODUCT}"
    if /tmp/packer build *.json ; then
      echo -e "\033[32m${PRODUCT} \033[1m[PASS]\033[0m"
    else
      echo -e "\033[31m${PRODUCT} \033[1m[FAIL]\033[0m"
      return 1
    fi
    cd -
  done
  echo "Cleaning up GPG Keyring ...                   "
  gpg --fingerprint --with-colons ${PGP_SECRET_ID} |\
    grep "^fpr" |\
    sed -n 's/^fpr:::::::::\([[:alnum:]]\+\):/\1/p' |\
    xargs gpg --batch --delete-secret-keys
  echo "Resetting vars for subsequent runs ...        "
  export VAULT_VERSION="${VAULT_RELEASE}"
  export CONSUL_VERSION="${CONSUL_RELEASE}"
}