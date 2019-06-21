#!/bin/bash
TAG=$1
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 tag_number" >&2
  exit 1
fi

if [ -z "$(git status --porcelain)" ]; then 
    swift test && git tag $TAG && git push && git push --tag
else 
    echo "git dir is dirty"
    exit 1
fi

