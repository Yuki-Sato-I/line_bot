desc "This task is called by the Heroku scheduler add-on"
task :update_feed => :environment do
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'nokogiri'
  require 'kconv'
  require 'rexml/document'

  client ||= Line::Bot::Client.new { |config|
    config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
    config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
  }

  # 使用したxmlデータ（毎日朝6時更新）：以下URLを入力すれば見ることができます。
  URL  = "https://news.yahoo.co.jp/topics"
  charset = nil

  html = open(URL) do |page|
    #文字コードを取得して
    charset = page.charset
    #ページを読む
    page.read
  end

  docs = Nokogiri::HTML.parse(html,nil,charset).css('.list').inner_html
  news_url = docs.scan(/<li><a href="(?<html_url>.+?)"/)
  titles = docs.scan(/onmousedown=.+\/pickup\/.+'">(?<html_title>.+?)</)

  dates = {}
  a = []
  b = []
  news_url.size.times do |n|
    dates.store(titles[n][0], news_url[n][0])
    a << titles[n][0]
    b << news_url[n][0]
  end

  users = User.all

  users.each do |user|
    # 発信するメッセージの設定
    push = "君が登録したワードのニュースはこれだよ。\n"
    message = {
      type: 'text',
      text: push
    }
    response = client.push_message(user.line_id, message)

    if user.keywords.present? #keyword登録されていたら
      # ここに配列からキーワードのニュースを取り出す処理を書き込む。それらをurlと共に、メッセージに入れる。（pushに付け足す）
      user.keywords.each do |keyword|
        push = "#{keyword}が含まれているトップニュース\n"
        dates.each do |title, url|
          if /#{keyword}/ =~ title #タイトルにキーワードが含まれていたら
            push += "#{title}\n #{url}\n"
          end
        end
        message = {
          type: 'text',
          text: push
        }
        response = client.push_message(user.line_id, message)
      end
    else #keyword登録されていなかったら
      push = "登録しているワードはないよ。"
      message = {
        type: 'text',
        text: push
      }
      response = client.push_message(user.line_id, message)
    end
  end
  "OK"
end