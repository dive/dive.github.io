#!/bin/sh -e

echo "Removing the old website"
pushd public
git rm -rf *
popd

echo "Deploying updates to GitHub..."
hugo -t blank

pushd public
git add .
git commit -m "rebuilding site $(date)"
popd

git push origin master
