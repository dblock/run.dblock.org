# frozen_string_literal: true

require 'date'

module Jekyll
  class CalendarPages < Generator
    safe true
    priority :high

    def generate(site)
      activities = site.posts.docs.select do |post|
        post.data['strava_id'] && post.data.fetch('tags', []).include?('runs')
      end
      return if activities.empty?

      by_date = activities.group_by { |post| post.date.to_date }
      current_year = site.time.year
      years = (by_date.keys.map(&:year) + [current_year]).uniq.sort.reverse
      site.data['calendar_years'] = years

      years.each do |year|
        page = PageWithoutAFile.new(site, site.source, "cal/#{year}", 'index.html')
        page.data = {
          'layout' => 'calendar',
          'title' => "Calendar #{year}",
          'calendar_year' => year,
          'calendar_current_year' => current_year,
          'calendar_years' => years,
          'calendar_months' => months_for(year, by_date),
          'run_count' => by_date.sum { |date, posts| date.year == year ? posts.length : 0 },
          'active_days' => by_date.count { |date, _posts| date.year == year },
          'total_miles' => by_date.sum do |date, posts|
            date.year == year ? posts.sum { |post| post.data.fetch('distance', 0).to_f } : 0
          end,
          'permalink' => year == current_year ? '/cal/' : "/cal/#{year}/"
        }
        site.pages << page
      end
    end

    private

    def months_for(year, by_date)
      (1..12).map do |month|
        first = Date.new(year, month, 1)
        last = Date.new(year, month, -1)
        month_days = (first..last).map { |date| day_data(date, by_date.fetch(date, [])) }
        weeks = Array.new(first.wday, nil) + month_days
        weeks.concat(Array.new((7 - weeks.length % 7) % 7, nil))
        {
          'name' => first.strftime('%B'),
          'miles' => month_days.sum { |day| day.fetch('miles') },
          'runs' => month_days.sum { |day| day.fetch('count') },
          'weeks' => weeks.each_slice(7).map { |week| week.map { |day| day || {} } }
        }
      end
    end

    def day_data(date, posts)
      miles = posts.sum { |post| post.data.fetch('distance', 0).to_f }
      titles = posts.map { |post| post.data.fetch('title') }
      intensity = if miles >= 10
                    4
                  elsif miles >= 6
                    3
                  elsif miles >= 3
                    2
                  elsif miles.positive?
                    1
                  else
                    0
                  end
      {
        'day' => date.day,
        'count' => posts.length,
        'miles' => miles,
        'miles_display' => format('%.1f', miles),
        'intensity' => intensity,
        'url' => posts.first&.url,
        'title' => titles.join('; ')
      }
    end
  end
end
