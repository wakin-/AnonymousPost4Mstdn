require 'bundler/setup'
require 'yaml'
require 'mastodon'
require 'sanitize'
require 'open-uri'
require 'cgi'
require 'time'
require 'active_support/time'

config = YAML.load_file("./key.yml")
debug = false

post_message = !config["post_message"].nil? ? config["post_message"] : "\n📩 [acct]"

icon_config = File.exist?("./icon.yml") ? open('./icon.yml', 'r') { |f| YAML.load(f) } : {}

def open_mention_response()
  mention_response = File.exist?("./mention_response.yml") ? open('./mention_response.yml', 'r') { |f| YAML.load(f) } : {'mention_response' => {}}
  return mention_response && mention_response['mention_response'] ? mention_response['mention_response'] : {}
end

def save_mention_response(mention_response)
  file = File.open("./mention_response.yml", 'w')
  YAML.dump({'mention_response' => mention_response}, file)
  file.close
end

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

def disp_acct(acct, config)
  return acct + (!(acct.match(/@/)) ? "@#{config['base_url']}" : '')  
end

def proc_toot_boost_request(content, toot, rest, debug, config)
  acct = disp_acct(toot.attributes["account"]["acct"], config)

  toot_url_pattern = /https:\/\/[\S]+/

  scan = content.scan(toot_url_pattern)
  p scan if debug
  if scan
    scan.each {|match|
      response = rest.search(match)

      if response.statuses.size > 0

        if config["boost_allow_list"] && !config["boost_allow_list"].index(acct)
          content = "@"+toot.attributes["account"]["acct"]+" すみません。URLブーストは許可されていません。"
          rest.create_status(content, visibility: "direct", in_reply_to_id: toot.attributes["status"]["id"])
          return
        end

        response.statuses.each {|status|
          p status.attributes["id"] if debug

          rest.reblog(status.attributes["id"])
        }

        content.gsub!(Regexp.new("\s*#{match}\s*"), "")
      end
    }
  end
end

def add_post_content(content, toot, icon_config, config, post_message)
  id = toot.status.account.id
  content = icon_config[id] + " " + content if icon_config[id] && !icon_config[id].empty?

  acct = disp_acct(toot.status.account.acct, config)
  content += post_message.gsub(/\[acct\]/, acct)
  content += " ##{config['hashtag']}" if config['hashtag']
  return content
end

def add_mention_response_id(mention_response, mention_id, response_id, created_at)
  mention_response.store(mention_id, {
    "response_id" => response_id,
    "created_at" => created_at
  })
end

def check_keep_id_day_config(config)
  return config["keep_id_day"] && config["keep_id_day"].kind_of?(Integer) && config["keep_id_day"] >= 0
end

def check_mention_response(mention_response, config, debug)
  if check_keep_id_day_config(config)
    mention_response.each {|id, mr|
      if mr['created_at'].in_time_zone('Tokyo') < Time.current.ago(config["keep_id_day"].days)
        mention_response.delete(id)
        p "#{id} deleted" if debug
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
          proc_toot_boost_request(content, toot, rest, debug, config)

          next if content.empty? || content.match(/^\s+$/)

          content = add_post_content(content, toot, icon_config, config, post_message)

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
            p "deleted: #{u}" if debug
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

          response = rest.create_status(content, sensitive: toot.status.attributes["sensitive"], spoiler_text: toot.status.attributes["spoiler_text"], media_ids: uml)

          mention_response = open_mention_response()

          add_mention_response_id(mention_response, toot.status.attributes["id"], response.attributes["id"], toot.status.attributes["created_at"]) if check_keep_id_day_config(config)

          check_mention_response(mention_response, config, debug)

          save_mention_response(mention_response)
#        end
      elsif toot.type == "favourite" then
        mention_response = open_mention_response()

        mention_response.select {|id, mr| mr["response_id"] == toot.status.id }.each_key {|key|
          mention = rest.status(key)

          acct = disp_acct(toot.attributes["account"]["acct"], config)

          content = "@"+mention.attributes["account"]["acct"]+" "+acct+"さんがお気に入りにしました"
          p content if debug
          rest.create_status(content, visibility: "direct", in_reply_to_id: mention.attributes["id"])
        }
      elsif toot.type == "reblog" then
        mention_response = open_mention_response()

        mention_response.select {|id, mr| mr["response_id"] == toot.status.id }.each_key {|key|
          mention = rest.status(key)

          acct = disp_acct(toot.attributes["account"]["acct"], config)
          content = "@"+mention.attributes["account"]["acct"]+" "+acct+"さんがブーストしました"
          p content if debug
          rest.create_status(content, visibility: "direct", in_reply_to_id: mention.attributes["id"])
        }
      end
    elsif toot.kind_of?(Mastodon::Streaming::DeletedStatus) then
      mention_response = open_mention_response()

      response_id = mention_response && mention_response[toot.id.to_s] ? mention_response[toot.id.to_s]["response_id"] : false
      if response_id
        rest.destroy_status(response_id)

        mention_response.delete(toot.id.to_s)

        save_mention_response(mention_response)
      end
    end
  end
rescue => e
  p "error"
  puts e
  retry
end
