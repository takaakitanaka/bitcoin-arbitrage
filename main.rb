require 'dotenv/load'
require 'slack/incoming/webhooks'

require_relative 'lib/coincheck'
require_relative 'lib/zaif'

def output msg
  if ENV['RUN_ON_HEROKU'].nil?
    p msg
  else
    slack = Slack::Incoming::Webhooks.new ENV['SLACK_WEBHOOK_URL']
    slack.post msg
  end
end

def generate_stat service, r
  result = <<"EOS"
*#{service} BTC/JPY*
   bid: #{r['bid']}
   ask: #{r['ask']}
EOS
  result
end

def profit? trade_amount, bid, ask
  margin = ask - bid
  (trade_amount * margin).floor - ENV['MIN_VOLUME_JPY'].to_f > 0
end

def trading bidc, bid, askc, ask, trade_amount
  if profit?(trade_amount, bid, ask) &&
      bidc.has_jpy?(bid, trade_amount) &&
      askc.has_btc?(trade_amount)
    output "Buying  #{trade_amount}BTC #{(bid*trade_amount).floor}JPY in #{bidc.service}"
    # bidc.buy(bid, trade_amount)
    output "Selling #{trade_amount}BTC #{(ask*trade_amount).floor}JPY in #{askc.service}"
    # askc.sell(ask, trade_amount)
    output "Profit #{((ask-bid) * margin).floor}JPY"
  end
end

def run
  trade_amount = ENV['TRADE_AMOUNT'].to_f
  zc = ZaifWrapper.new ENV['ZAIF_KEY'], ENV['ZAIF_SECRET']
  cc = CoincheckWrapper.new ENV['COINCHECK_KEY'], ENV['COINCHECK_SECRET']

  output "Trading amount: #{trade_amount}BTC"
  output "Minimum valume: #{ENV['MIN_VOLUME_JPY']}JPY"

  zr = zc.ticker
  output generate_stat zc.service, zc.ticker
  cr = cc.ticker
  output generate_stat cc.service, cr

  trading zc, zr['bid'], cc, cr['ask'], trade_amount
  trading cc, cr['bid'], zc, zr['ask'], trade_amount
end

if ENV['RUN_ON_HEROKU'].nil?
  loop do
    run
    sleep(5)
  end
else
  run
end
