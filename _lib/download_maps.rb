require 'fileutils'
require 'cgi'
require 'httparty'

directory = '_posts/**/'

pattern = Regexp.new(
  "{% raw %}\n<img src='(https:\/\/maps\.googleapis\.com\/maps\/api\/staticmap\?.*?)'>\n{% endraw %}", Regexp::MULTILINE
)

Dir.glob(File.join(directory, '*.md')) do |file_path|
  puts file_path
  content = File.read(file_path)

  if match = content.match(pattern)
    url = match[1]
    png_path = file_path.gsub('_posts/', 'images/maps/').gsub('.md', '.png')
    unless File.exist?(png_path)
      png = HTTParty.get(url).body
      FileUtils.mkdir_p(File.dirname(png_path))
      File.write(png_path, png)
    end
    puts " #{png_path}"
    modified_content = content.gsub(match.to_s, "![]({{ site.url }}/#{png_path})")
    File.write(file_path, modified_content)
  end
rescue StandardError => e
  puts "Error processing #{file_path}: #{e.message}"
end
