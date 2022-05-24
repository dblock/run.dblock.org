# CI Cron

This project uses [a cronjob](.github/workflows/strava.yml) to automatically sync with Strava twice a day.

## Strava Tokens

Create an app and obtain a Strava Client ID and secret from [strava.com/settings/api](https://www.strava.com/settings/api).

Run `strava-oauth-token` and note the `refresh_token` and `access_token`.

Set `STRAVA_CLIENT_SECRET` and `STRAVA_API_REFRESH_TOKEN` in repo settings under Secrets/Actions.
