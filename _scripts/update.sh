#!/bin/bash

set -e
set -o pipefail

bundle exec rake nyrr:results:update
bundle exec rake strava:update
bundle exec rake tags

gh_token="${GH_TOKEN-}"

if [ -z "$gh_token" ]
then
  echo "GH_TOKEN is not set. Cannot proceed." >&2
  exit 1
fi

git config --global user.name "Run Buildbot"
git config --global user.email "dblock+run@dblock.org"
git add .
if ! git diff --quiet --staged
  then
    git commit -m "Updated from Strava, `date +%Y/%m/%d`."
    git push "https://${GH_TOKEN}@github.com/${TRAVIS_REPO_SLUG}.git" HEAD:gh-pages
 else
   echo "Nothing has changed! I hope that's what you expected." >&2
fi
