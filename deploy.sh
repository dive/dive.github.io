#!/bin/sh -e

printf "Deploying updates to GitHub..."

hugo -t blank

cd public
git add .
msg="rebuilding site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"

git push origin master
