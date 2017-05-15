require 'rubygems'
require 'sinatra'
require 'sinatra/namespace'
require 'sequel'
require 'mysql2'
require 'json'
require 'date'

#constants
TRADES_DEFAULT = 100
PORT = 3000
VERSION = '/v0.2'

#DB connection
DB = Sequel.connect(adapter: :mysql2, database: 'dbp', host: 'localhost', user: 'dbpadmin', password: 'password')

class MyApp < Sinatra::Base
	register Sinatra::Namespace

	before do
		content_type :json
	end

#0.0.0.0 for making the server availbale from anywhere
set :bind, '0.0.0.0'
set :port, PORT

namespace VERSION do

get '/isins' do
	content_type :json
	response['Access-Control-Allow-Origin'] = '*'
	
	#parameters
	startsWith = params[:startsWith]
	limit = params[:limit]
	puts "********** GET params **********\nstartsWith: #{startsWith}\nlimit: #{limit}\n********************************"
	# using prefix?
	if (startsWith.to_s.empty?)
		isins=DB[:dbp_trades].select(:isin).distinct
	else
		puts startsWith
		startsWith.upcase!
		isins=DB[:dbp_trades].select(:isin).distinct.grep(:isin, "#{startsWith}%")
	end
	total = isins.count
	if (limit != nil)
		isins = isins.limit(limit)
	end
	returnJson = {"returned" => isins.count, "total" => total, "isins" => isins.all}
	returnJson.to_json
end

get '/trades/:isin' do
	
	response['Access-Control-Allow-Origin'] = '*'
	#parameters
	isin = params[:isin].upcase
	dateTimeFrom = params[:dateTimeFrom]
	dateTimeTo = params[:dateTimeTo]
	samples = params[:samples]
	
	# parameters validation
	if (dateTimeFrom == nil)
		halt 400, "dateTimeFrom missing"
	end
	dateTimeFrom = Time.parse(dateTimeFrom) rescue nil
	if (!dateTimeFrom)
		halt 400, "Wrong format of dateTimeFrom parameter"
	else
		puts dateTimeFrom
	end
	minDBTime = DB[:dbp_trades].min(:time)
	puts "minDBTime: #{minDBTime}"
	if (dateTimeFrom < minDBTime)
		dateTimeFrom = minDBTime
	end
	
	if (dateTimeTo == nil)
		halt 400, "dateTimeTo missing"
	end
	dateTimeTo = Time.parse(dateTimeTo) rescue nil
	if (!dateTimeTo)
		halt 400, "Wrong format of dateTimeTo parameter"
	else
		puts dateTimeTo
	end
	maxDBTime = DB[:dbp_trades].max(:time)
	puts "maxDBTime: #{maxDBTime}"
	if (dateTimeTo > maxDBTime)
		dateTimeTo = maxDBTime
	end

	#default value for samples
	if (samples == nil)
		samples = TRADES_DEFAULT
	else
		samples = Integer(samples) rescue nil
		if (!samples)
			halt 400, "Wrong format of samples parameter"
		else
			puts samples
		end
	end

	content_type :json
	
	uTimeFrom = dateTimeFrom.to_time.to_i
	uTimeTo = dateTimeTo.to_time.to_i
	
	puts "********** GET params **********\nisin: #{isin}\ndateTimeFrom: #{dateTimeFrom}\ndateTimeTo: #{dateTimeTo}\nsamples: #{samples}\n********************************"

	#exists any trade?
	trades = DB[:dbp_trades].select( :time, :price, :volume).where(:isin=>isin).limit(1)
	if (trades.count == 0)
		halt 404, "There are no trades for specified ISIN"
	else
		#trades = DB[:dbp_trades].select( :time, :price, :volume).where(:isin=>isin).where(Sequel.lit('time >= ?', dateTimeFrom)).where(Sequel.lit('time <= ?', dateTimeTo))

		currency = trades.select(:currency).exclude(:currency => "").first[:currency]
		puts currency

		uTimeStep = ((uTimeTo-uTimeFrom)/samples)
		returnTrades = Array.new
		index = uTimeFrom
		sameTrade = 0
		while index < uTimeTo do
			#puts index
			indexTime = DateTime.strptime(index.to_s, '%s')
			#puts "======="
			#puts "indexTime: #{indexTime}"
			trade = DB[:dbp_trades].select( :time, :price, :volume).where(:isin=>isin).where(Sequel.lit('time >= ?', indexTime)).where(Sequel.lit('time <= ?', dateTimeTo)).first
			index += uTimeStep
			if (trade != nil)
				#puts "trade time: #{trade[:time]}"
				if (!trade.to_s.empty?) 
					returnTrades.push(trade)
				end
			end

		end
		
		returnedCount = returnTrades.count
		return_json = {"isin" => isin, "currency" => currency, "returned" => returnedCount, "trades" => returnTrades}
		return_json.to_json
	end
end	
end

run! if app_file == $0
end
