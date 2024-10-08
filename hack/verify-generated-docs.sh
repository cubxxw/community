#!/usr/bin/env bash

# Copyright 2018 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

CRT_DIR=$(pwd)
VERIFY_TEMP=$(mktemp -d 2>/dev/null || mktemp -d -t k8s-community.XXXXXX)
WORKING_DIR="${VERIFY_TEMP}/src/testgendocs"
mkdir -p "${WORKING_DIR}"

function cleanup {
  rm -rf "${VERIFY_TEMP}"
}
trap cleanup EXIT

function get_interesting_files() {
  local dir=$1
  local files=$(ls ${dir}/sigs.yaml ${dir}/sig-*/README.md ${dir}/wg-*/README.md ${dir}/committee-*/README.md ${dir}/sig-list.md ${dir}/OWNERS_ALIASES)
  echo "$files"
}

git archive --format=tar "$(git write-tree)" | (cd "${WORKING_DIR}" && tar xf -)

cd "${WORKING_DIR}"
make 1>/dev/null

mismatches=0
break=$(printf "=%.0s" $(seq 1 68))


real_files=$(get_interesting_files "$CRT_DIR")
for file in $real_files; do
  real=${file#$CRT_DIR/}
  if ! diff -q ${file} ${WORKING_DIR}/${real} &>/dev/null; then
    echo "${file} does not match ${WORKING_DIR}/${real}";
    mismatches=$((mismatches+1))
  fi;
done

real_files_count=$(echo "$real_files" | wc -w)
working_dir_files_count=$(get_interesting_files "${WORKING_DIR}" | wc -l)

if [[ $real_files_count -ne $working_dir_files_count ]]; then
  echo "Mismatch: Number of generated files in does not match the number of files in the repository."
  mismatches=$((mismatches+1))
fi

if [[ ${mismatches} -gt "0" ]]; then
  echo ""
  echo "${break}"
  noun="mismatch was"
  if [ ${mismatches} -gt "0" ]; then
    noun="mismatches were"
  fi
  echo "${mismatches} ${noun} detected."
  echo "Do not manually edit sig-list.md or README.md files inside the sig folders."
  echo "Instead make your changes to sigs.yaml, then run \`make\`, and then"
  echo "commit your changes to sigs.yaml and any generated docs.";
  echo "${break}"
  exit 1;
fi

exit 0
