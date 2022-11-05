---
layout: page
title: About
tags: [about, me me]
comments: false
permalink: '/about/'
---

Hi! This is my running blog. It automatically synchronizes and publishes my runs. Please [follow me on Strava](https://www.strava.com/athletes/dblockdotorg).

I always hated running. And now I have a running blog. Read [Why do I run?](/2017/10/01/why-do-i-run.html) or [My Running Gear in 2018](/2018/03/04/my-running-gear-in-2018.html). If you're new to running, read [How to Run a Race in NYC](/2018/03/17/how-to-run-a-race-in-nyc-financials-charity.html). I also ran my first marathon in NYC in 2018. You can definitely [do it](/2018/11/05/how-to-run-your-first-nyc-marathon.html), too!

{% include _totals.html %}

Since {{ site.posts.last.date | date: "%Y" }}, I've run a total of {{ total_distance | round: 1 }} miles in {{ total_time | divided_by: 3600.0 | round }} hours.

I built and operate a [Slack bot for Strava](https://slava.playplay.io) service that publishes Strava runs into Slack. [Install it](https://slava.playplay.io) into your team's Slack and motivate your coworkers to go the distance.

Like what you read here? Have questions? <a href='https://github.com/dblock/run.dblock.org/issues/new'>Open an issue</a> for this blog. Feel free to <a href='mailto:dblock@dblock.org'>e-mail me</a>, too.

Finally, if you had enough of running, check out [my art blog](http://art.dblock.org) and [my tech blog](http://code.dblock.org).

![]({{ site.url }}/images/shoes.jpg)
