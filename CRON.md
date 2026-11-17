# CI Cron

This project uses [a cronjob](.github/workflows/strava.yml) to automatically sync with Strava twice a day.

After a successful sync, the cronjob explicitly dispatches the Pages deployment workflow. Pushes made with `GITHUB_TOKEN` do not trigger push workflows.

## Google Maps Credentials

The downloader uses a dedicated API key restricted to the Maps Static API and signs requests with the project's URL signing secret. GitHub-hosted runners do not have fixed outbound IPs, so this key has no website or IP application restriction; signatures must be enforced through the Maps Static API unsigned-request quota after migration.

Store the downloader key in the GitHub Actions secret `GOOGLE_STATIC_MAPS_SERVER_API_KEY` and the URL signing secret from the Google Maps Platform Credentials page in `GOOGLE_STATIC_MAPS_URL_SIGNING_SECRET`. Generate an initial signing secret if none exists; otherwise use the current secret without regenerating it, since regeneration invalidates existing signatures after the grace period. Use the same variable names, `GOOGLE_STATIC_MAPS_SERVER_API_KEY` and `GOOGLE_STATIC_MAPS_URL_SIGNING_SECRET`, in the workflow and local `.env`. Never commit either credential.

After deploying and verifying signed downloads, confirm that no other callers in the project need unsigned requests, then set the Maps Static API unsigned-request quota to zero. This quota is project-wide, so changing it before migrating other callers can break them. Existing downloaded map images do not need regeneration.

Run `bundle exec rspec` to check URL signing, credential errors, actual HTTP request encoding, download caching, and rejection of unsuccessful or non-PNG responses without contacting Google. Pull request CI runs these specs and builds the site with `bundle exec jekyll build --quiet`.

## Strava Tokens

Create an app and obtain a Strava Client ID and secret from [strava.com/settings/api](https://www.strava.com/settings/api).

Run `strava-oauth-token` and note the `refresh_token` and `access_token`.

Set `STRAVA_CLIENT_SECRET` and `STRAVA_API_REFRESH_TOKEN` in repo settings under Secrets/Actions.
