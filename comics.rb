#! /usr/bin/ruby

require 'yaml'
require 'net/http'
require 'cgi'

IN_FILE = File.join(File.dirname(__FILE__), 'comics.yaml')
OUT_FILE = File.join(File.dirname(__FILE__), 'comics.html')

HEADER = <<-HEAD
<html>
<head>
  <title>#{Date::DAYNAMES[Date.today.wday]} Comics</title>
  <style>
    a { text-decoration: none; }
    img { border: 0; margin-top: 5px; }
    p { margin: 20px; }
  </style>
</head>
<body>
HEAD

def match(html, regexp_str, subgroup, url)
  return nil unless regexp_str
  
  regexp = eval(regexp_str)
  
  if regexp.is_a?(Regexp)
    match = html.match(regexp)
    if match
      match = match[subgroup.to_i];
      match.gsub!(/(src=|href=)['"]?([^"' ]+)['"]?/) { $1 + '"' + URI.join(url, $2).to_s + '"' }
      match
    end
  elsif regexp
    raise TypeError.new("#{str.inspect} did not eval to a Regexp")
  end
end

def default_src(url = '')
  if url =~ /http:\/\/(www.)?comics\.com/
    '/http.*?full.gif/'
  elsif url =~ /gocomics\.com/
    '/http.*?\/assets.amuniversal.com[^\'"]*/'
  elsif url =~ /uclick\.com/
    '/\/feature.*?gif/'
  else
    '/[^\'"]+comic[^\'"\.]*(\.gif|\.png|\.jpe?g)/i'
  end
end


comics = YAML.load(File.new(IN_FILE))

File.open(OUT_FILE, 'w') do |file|
  file << HEADER
  
  for comic in comics
    begin
      url = comic['url'] || eval(comic['urlexp'])
      next unless url
      
      # Make http request, following one redirect if necessary
      case response = Net::HTTP.get_response(URI.parse(url))
      when Net::HTTPSuccess 
        html = response.body
      when Net::HTTPRedirection
        html = Net::HTTP.get(uri = URI.join(url, response['location']))
        url = uri.to_s
      end
      
      # extract whole <img> tag
      img = match html, comic['img'], comic['subgroup'], url
      
      if img.nil?  # extract just image src
        src = match html, comic['src'] || default_src(url), comic['subgroup'], url
        src = src ? URI.join(url, src).to_s : 'error.png'
        
        # title text
        tt = match html, comic['title_text'], comic['tt_subgroup'], url
        
        img = "<img src=\"#{src}\" title=\"#{tt}\">"
      end
      
      # info text appears above image (title, extra joke, etc.)
      info = match html, comic['info'], comic['info_subgroup'], url
      
      name = comic['name'] || html.match(/<title>([^<]+)/)[1]
      href = comic['href'] || eval(comic['hrefexp'].to_s) || url
      
      file << "<p><b>#{name}</b><br>\n"
      file << "#{info}<br>\n" if info
      file << "  <a href=\"#{url}\">\n    "
      file << img
      file << "\n  </a>\n</p>\n"
    
    rescue Exception => e
      file << "<p>Error for #{comic['name'] || '?'}: #{e.to_s}</p><br>"
      puts e.to_s
      puts e.backtrace
    end
  end
  
  file << "<a href='txmt://open/?url=file://#{File.expand_path(IN_FILE)}'>edit comics list</a>\n"
  file << "</body>\n</html>"
end

`open #{OUT_FILE}`

