#!/bin/bash

new_version="$1"
shift #removes version from list of arguments

if [[ ! "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid version format. Use full semver: X.Y.Z, X.Y.Z-alpha, etc."
  exit 1
fi

for file in "$@"; do # loop over the rest of the arguments and replace content directly in the file
  sed -Ei "/# x-patch-semver/ {
    s/[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?/$new_version/
  }" "$file"
done