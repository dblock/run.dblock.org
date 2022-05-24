#!/bin/bash

set -e
set -o pipefail

bundle exec rake nyrr:results:update
bundle exec rake strava:update
bundle exec rake tags

git config --global user.name "Run Cron"
git config --global user.email "dblock+run@dblock.org"
git add .
if ! git diff --quiet --staged
  then
    git commit -m "Updated from Strava, `date +%Y/%m/%d`."
    git push origin HEAD:gh-pages
 else
   echo "Nothing has changed! I hope that's what you expected." >&2
fi
