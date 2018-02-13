require 'bundler/setup'
require 'yaml'
require 'mastodon'
require 'sanitize'
require 'open-uri'
require 'cgi'

config = YAML.load_file("./key.yml")
debug = false

icon_config = File.exist?("./icon.yml") ? open('./icon.yml', 'r') { |f| YAML.load(f) } : {}

stream = Mastodon::Streaming::Client.new(
  base_url: "https://" + config["base_url"],
  bearer_token: config["access_token"])

rest = Mastodon::REST::Client.new(
  base_url: "https://" + config["base_url"],
  bearer_token: config["access_token"])

account = rest.verify_credentials().acct

def proc_icon_set_request(content, toot, icon_config, rest, debug)
  icon_set_pattern = /icon=\[([^\]]+)\]/

  match = content.match(icon_set_pattern)
  if match
    icon = match[1]
    id = toot.status.account.id
    p "#{id}: #{icon}" if debug
    icon_config[id] = icon
    YAML.dump(icon_config, File.open('./icon.yml', 'w'))

    response = "@#{toot.status.account.acct} your icon is \"#{icon}\""
    p "in_reply_to: "+toot.status.attributes["id"] if debug
    rest.create_status(response, sensitive: toot.status.attributes["sensitive"], spoiler_text: toot.status.attributes["spoiler_text"], in_reply_to_id: toot.status.attributes["id"], visibility: toot.status.attributes["visibility"])
  end

  content.gsub!(icon_set_pattern, "")
end

def proc_toot_boost_request(content, toot, rest, debug)
  toot_url_pattern = /https:\/\/[\S]+/

  scan = content.scan(toot_url_pattern)
  p scan if debug
  if scan
    scan.each {|match|
      response = rest.search(match)

      if response.statuses.size > 0
        response.statuses.each {|status|
          p status.attributes["id"] if debug

          rest.reblog(status.attributes["id"])
        }

        content.gsub!(Regexp.new("\s*#{match}\s*"), "")
      end
    }
  end
end

begin
  stream.user() do |toot|
    if toot.kind_of?(Mastodon::Notification) then
      if toot.type == "mention" then
        content = toot.status.content
        content.gsub!(/<br\s?\/?>/, "\n")
        content.gsub!("</p><p>", "\n\n")
        content = Sanitize.clean(content).strip
        content = CGI.unescapeHTML(content)

        p "@#{toot.status.account.acct}: #{content}" if debug
#        if toot.status.visibility == "direct" then
          content.gsub!(Regexp.new("\s*@#{account}\s*", Regexp::IGNORECASE), "")

          proc_icon_set_request(content, toot, icon_config, rest, debug)
          proc_toot_boost_request(content, toot, rest, debug)

          next if content.empty? || content.match(/^\s$/)

          content += "\n📩 #{toot.status.account.acct}" +(!(toot.status.account.acct.match(/@/)) ? "@#{config['base_url']}" : '')
          content += " ##{config['hashtag']}" if config['hashtag']

          id = toot.status.account.id
          content = icon_config[id] + " " + content if icon_config[id] && !icon_config[id].empty?

          p "画像あり" if !(toot.status.media_attachments == []) && debug
          imgs = []
          o_imgt = []
          toot.status.media_attachments.each {|ml|
            imgs << ml.id
            o_imgt << ml.attributes["text_url"]
            open(ml.id, "wb") {|mid|
              open(ml.url) {|mu|
                mid.write(mu.read)
                p "saved: #{ml.id}" if debug
              }
            }
          }
          uml = []
          n_imgt = []
          imgs.each {|u|
            media = rest.upload_media(u)
            uml << media.id
            n_imgt << media.attributes["text_url"]
            p "uploaded: #{u}" if debug
            File.delete(u)
            p "delete: #{u}" if debug
          }
          if !(toot.status.media_attachments == []) && !(o_imgt.include?(nil)) then
            imgt = [o_imgt, n_imgt].transpose
            imgt = Hash[*imgt.flatten]
            content = content.gsub(Regexp.union(o_imgt), imgt)
          end
          content = 0x200B.chr("UTF-8") if content.empty? && !(uml.empty?)
          p "spoiler text: #{toot.status.attributes["spoiler_text"]}" if debug
          p "content: #{content}" if debug
          p "media: #{uml}" if debug
          p "sensitive?: #{toot.status.attributes["sensitive"]}" if debug

          rest.create_status(content, sensitive: toot.status.attributes["sensitive"], spoiler_text: toot.status.attributes["spoiler_text"], media_ids: uml)
#        end
      end
    end
  end
rescue => e
  p "error"
  puts e
  retry
end
