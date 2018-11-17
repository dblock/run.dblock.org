# Travis CI Cron

This project uses a Travis CI cronjob to automatically sync with Strava once a day.

## Strava Token

Create an app and obtain a Strava Client ID and secret from [strava.com/settings/api](https://www.strava.com/settings/api). Set it as `STRAVA_CLIENT_ID` and `STRAVA_CLIENT_SECRET` in Travis-CI configuration pages.

Run `bundle exec ruby _bin/strava_oauth` and follow instructions to get a `refresh_token` and `access_token`.

Add the refresh token with `travis encrypt STRAVA_API_REFRESH_TOKEN=... --add env` to .travis.yml and commit it.

## Github Token

To commit to Github you need a `public_repo` permission token. Create one in [github.com/settings/tokens](https://github.com/settings/tokens). Set it as `GH_TOKEN` in Travis-CI configuration settings.
