require 'dotenv'
require 'mechanize'
require 'uri'

class Scrapper
  def self.agent
    @_agent = @_agent || Mechanize.new
  end

  def self.scrapper_domain
    ENV['scrapper_domain']
  end

  def self.login
    page = agent.get("https://#{scrapper_domain}/signin")
  
    tth_form = page.form
    tth_form.field_with(name: 'user_session[email]').value = ENV['email']
    tth_form.field_with(name: 'user_session[password]').value = ENV['password']
  
    page = agent.submit(tth_form)
  end
  
  def self.iterate_topic(topic)
    page = agent.get(topic)
  
    page.parser.css('li.course .card-box').map do |l|
      l.attributes['href'].value
    end
  end
  
  def self.iterate_stages(stages)
    page = agent.get(stages)
  
    page.parser.css('.steps-list li a').select{ |elem|
      # only retrieve videos, should contains duration (eg: 3:12)
      elem.children[5].children[0].text =~ /\d+:\d+/
    }.map do |l|
      l.attributes['href'].value
    end
  end
  
  def self.visit_stage(stage)
    page = agent.get(stage)
  
    puts "----- Stage: #{stage}"
  
    mp4_link = page.parser.css('source')[1].attributes['src'].value
    puts "+ link: #{mp4_link}"

    download(mp4_link)
  end
  
  def self.download(mp4_link)
    agent.pluggable_parser.default = Mechanize::Download
    file_name = URI(mp4_link).path.split('/').last
    agent.get(mp4_link).save("downloaded/#{file_name}")
  end

  def self.perform
    login
    links = iterate_topic("https://#{scrapper_domain}/library/topic:ruby")
    links.each do |link|
      # skip upcoming course
      next if link.split('/').last == 'upcoming'

      stages_link = iterate_stages("https://#{scrapper_domain + link}/stages")
      stages_link.each do |stage_link|
        visit_stage("https://#{scrapper_domain + stage_link}")
      end
    end
  end
end

Dotenv.load
Scrapper.perform
