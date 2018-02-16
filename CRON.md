# Travis CI Cron

This project uses a Travis CI cronjob to automatically sync with Strava once a day.

## Strava Token

Create an app and obtain a public token from [strava.com/settings/api](https://www.strava.com/settings/api). Set it as `STRAVA_API_TOKEN` in Travis-CI.

## Github Token

To commit to Github you need a `public_repo` permission token. Create one in [github.com/settings/tokens](https://github.com/settings/tokens). Set it as `GH_TOKEN` in Travis-CI.
