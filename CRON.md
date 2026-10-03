# CI Cron

This project uses [a cronjob](.github/workflows/strava.yml) to automatically sync with Strava twice a day.

After a successful sync, the cronjob explicitly dispatches the Pages deployment workflow. Pushes made with `GITHUB_TOKEN` do not trigger push workflows.

## Strava Tokens

Create an app and obtain a Strava Client ID and secret from [strava.com/settings/api](https://www.strava.com/settings/api).

Run `strava-oauth-token` and note the `refresh_token` and `access_token`.

Set `STRAVA_CLIENT_SECRET` and `STRAVA_API_REFRESH_TOKEN` in repo settings under Secrets/Actions.
