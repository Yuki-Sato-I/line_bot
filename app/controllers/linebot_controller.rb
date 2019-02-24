class LinebotController < ApplicationController
  require 'line/bot'  # gem 'line-bot-api'
  require 'open-uri'
  require 'kconv'
  require 'nokogiri'
  require 'rexml/document'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
    push = ""
    events = client.parse_events_from(body)
    events.each { |event|
      case event
        # メッセージが送信された場合の対応（機能①）
      when Line::Bot::Event::Message
        case event.type
          # ユーザーからテキスト形式のメッセージが送られて来た場合
        when Line::Bot::Event::MessageType::Text
          # event.message['text']：ユーザーから送られたメッセージ
          input = event.message['text']
          user = User.find_by(line_id: event['source']['userId'])
          case input
          when /.*(とうろく|登録).*/ # 一個ずつ登録させないといけない
            key = input.scan(/.*「(.+?)」.*/)
            unless Keyword.find_by(user_id: user.id, key: key[0][0]).present?
              key.each do |k|
                Keyword.create(user_id: user.id, key: k[0])
                push = "[#{k[0]}]登録したよ"
              end
            else
              push = "[#{key[0][0]}]はもう登録しているよ"
            end
          when /.*(一覧|itirann|いちらん).*/
            push = "あなたが登録しているキーワードはこれだよ\n"
            if user.keywords.present?
              user.keywords.each do |k|
                push += "[#{k.key}]\n"
              end
            else
              push = "登録しているキーワードはないよ"
            end
          when /.*(削除|さくじょ).*/
            key = input.scan(/.*「(.+?)」.*/)
            if Keyword.find_by(user_id: user.id, key: key[0][0]).present?
              Keyword.find_by(user_id: user.id, key: key[0][0]).destroy
              push = "[#{key[0][0]}]削除したよ"
            else
              push = "[#{key[0][0]}]は登録されていないよ"
            end
          # when /.*(トップ|ニュース|top).*/ あとで機能を改良するところ
          end
        else  # テキスト以外（画像等）のメッセージが送られた場合
          push = "テキスト以外はわからないよ〜"
        end
        message = {
          type: 'text',
          text: push
        }
        client.reply_message(event['replyToken'], message)
        # LINEお友達追された場合（機能②）
      when Line::Bot::Event::Follow
        # 登録したユーザーのidをユーザーテーブルに格納
        line_id = event['source']['userId']
        User.create(line_id: line_id)
        # LINEお友達解除された場合（機能③）
      when Line::Bot::Event::Unfollow
        # お友達解除したユーザーのデータをユーザーテーブルから削除
        line_id = event['source']['userId']
        User.find_by(line_id: line_id).destroy
      end
    }
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new { |config|
      config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
      config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
  end
end