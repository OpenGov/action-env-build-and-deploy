#!/bin/bash

source "${GITHUB_ACTION_PATH}/util.sh"

pathsToCopy="$1"

copy() {
  local row=$1
  local destination_base=$2

  _jq() {
    echo ${row} | jq -r ${1}
  }

  copy=$(_jq '.if')
  source=$(_jq '.source')
  target=$(_jq '.target')

  if [ "${copy}" = true ]; then
    echo "Copying from ${destination_base}/${target}"
    mkdir -p $(dirname "${destination_base}/${target}") && cp -r "${source}" "${destination_base}/${target}"
    [[ $3 == "git_add" ]] && git add "./${target}"
  else
    echo "Skipping copy to ${destination_base} for ${source}"
  fi
}

# Copy paths to render dir
echo Start copy include paths to rendered manifest
for row in $(echo "${pathsToCopy}" | jq -c '.[]'); do
  copy "${row}" "${RENDER_DIR}"
done

# Base changes off the branch being deployed to
set +e
# If the branch exists, check it out
if git ls-remote --exit-code --heads origin "refs/heads/${ENV_BRANCH}"; then
  git checkout "${ENV_BRANCH}" --
else
# If the branch does not exist, create it
  git checkout --orphan "${ENV_BRANCH}" --
  git rm -rf --ignore-unmatch '*'
  set -e
  # Ensure that branch will not be polluted with unrendered YAML
  rm -rf base/ env/
  git commit --allow-empty -m "Initial Commit"
  git push origin "${ENV_BRANCH}"
fi
set -e

git checkout -B "${PUSH_BRANCH}" --

echo "Cleaning staging area..."
git rm -rf --ignore-unmatch '*'
# Ensure that branch will not be polluted with unrendered YAML
rm -rf base/ env/
# Ensure that untracked files are cleaned up
git clean -fd
if is_debug; then
  echo "Post-staging cleanup status:"
  git status
fi

# If there are yaml files in RENDER_DIR (set by kustomize-build.sh), copy them
# to staging and commit, otherwise, output that there are no files in the
# rendered env.
FOUND_YAML=$(find "${RENDER_DIR?}" -name '*.y*ml')
if [[ -n "${FOUND_YAML}" ]]; then
  echo "Moving built k8s manifests into staging area..."
  if is_debug; then
    echo "[DEBUG] YAML files found in ${RENDER_DIR?}:"
    echo "[DEBUG] ${FOUND_YAML}"
  fi
  cp "${RENDER_DIR?}"/*.y*ml .
  git add --all -fv ./*.y*ml
else
  echo "No k8s manifests were built, staging area will be empty."
  # git add the removed files; hopefully no yaml pollution
  git add --all -fv .
fi

# Copy from render dir to branch
for row in $(echo "${pathsToCopy}" | jq -c '.[]'); do
  copy "${row}" "." "git_add"
done
