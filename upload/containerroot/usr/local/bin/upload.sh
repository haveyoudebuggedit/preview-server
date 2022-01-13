#!/bin/bash -e

cat <<EOF
** Welcome to the preview build deployment server! **

This server accepts a .tar.gz file on the standard input, unpacks the file
and deploys it as a preview build. The file must contain a deployment
descriptor named .deployment formatted as follows:

    CHANGE-ID: put_pull_request_id_here
    COMMIT-HASH: put_commit_hash_here
    REMOVE: true|false

To remove the preview deployment (e.g. when a PR is closed) please set the
REMOVE field to true.

The typical upload will work as follows:

    set -e
    echo "CHANGE_ID: ${PR_NUMBER}" >.deployment
    echo "COMMIT-HASH: $(git rev-parse HEAD)" >>.deployment
    echo "REMOVE: false" >>.deployment
    tar -czf - . | ssh this-server

If you have logged in via an interactive console, please press Ctrl+D now.
EOF

UPLOAD_FILE=/tmp/$$.tar.gz
TMP_DIR=/tmp/$$
mktemp "${UPLOAD_FILE}"
mktemp -d "${TMP_DIR}"
echo -e "\033[33;0mWaiting for .tar.gz archive to deploy on standard input...\033[0m"
cat >$UPLOAD_FILE
echo -e "\033[33;0mUpload finished, reading deployment descriptor...\033[0m"
mkdir -p
(cd $TMP_DIR && tar -xzf $UPLOAD_FILE .deployment)


CHANGE_ID=$(grep CHANGE-ID "${TMP_DIR}/.deployment" | awk '{ print $2 }')
if [ -z "${CHANGE_ID}" ]; then
  echo "\033[31;0mNo CHANGE-ID found in .deployment file. Did you add the .deployment file correctly?\033[0m"
  exit 1
fi
if ! [[ "$CHANGE_ID" =~ ^[a-zA-Z0-9_\-]+$ ]]; then
  echo "\033[31;0mThe CHANGE-ID contains invalid characters. Please adjust your .deployment file.\033[0m"
  exit 1
fi

COMMIT_HASH=$(grep COMMIT-HASH "${TMP_DIR}/.deployment" | awk '{ print $2 }')
if [ -z "${COMMIT_HASH}" ]; then
  echo "\033[31;0mNo COMMIT_HASH found in .deployment file. Did you add the .deployment file correctly?\033[0m"
  exit 1
fi
if ! [[ "$COMMIT_HASH" =~ ^[a-zA-Z0-9_\-]+$ ]]; then
  echo "\033[31;0mThe COMMIT-HASH contains invalid characters. Please adjust your .deployment file.\033[0m"
  exit 1
fi

REMOVE=$(grep REMOVE "${TMP_DIR}/.deployment" | awk '{ print $2 }')
if [ -z "${REMOVE}" ]; then
  echo "\033[31;0mNo REMOVE found in .deployment file. Did you add the .deployment file correctly?\033[0m"
  exit 1
fi
if ! [[ "$REMOVE" =~ ^(true|false)$ ]]; then
  echo "\033[31;0mThe COMMIT-HASH contains invalid characters. Please adjust your .deployment file.\033[0m"
  exit 1
fi

LOCKFILE="/tmp/${CHANGE_ID}.lock"
CHANGE_DIR="/var/www/${CHANGE_ID}"

(
  flock 200

  if [ "$REMOVE" = "true" ]; then
    echo -e "\033[33;0mRemoving all deployments for change...\033[0m"
    rm -rf "${CHANGE_DIR}"
    exit 0
  fi

  echo -e "\033[33;0mUnpacking archive...\033[0m"
  TARGET_DIR="${CHANGE_DIR}/${COMMIT_HASH}"
  mkdir -p "${TARGET_DIR}"
  (cd "${TARGET_DIR}" && tar -xzf "${UPLOAD_FILE}" && rm "${TARGET_DIR}/.deployment")

  echo -e "\033[33;0mChanging symlink to new deployment...\033[0m"
  SYMLINK="${CHANGE_DIR}/_htdocs"
  ln -s "${COMMIT_HASH}" "${SYMLINK}"

  echo -e "\033[33;0mRemoving old deployments...\033[0m"
  (cd "${CHANGE_DIR}" && rm $(ls "/var/www/${CHANGE_ID} | grep -v _htdocs | grep -v ${COMMIT_HASH}"))
) 200>"${LOCKFILE}"

echo -e "\033[33;0mDeployment finished.\033[0m"