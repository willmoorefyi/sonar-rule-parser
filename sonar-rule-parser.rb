#!/usr/bin/env ruby

require 'json'
require 'optparse'
require 'net/http'
require 'uri'

STATUS_CODES = {
	'BLOCKER' => 5,
	'CRITICAL' => 4,
	'MAJOR' => 3,
	'MINOR' => 2,
	'INFO' => 0
}

opts = {
	:sonar => 'http://localhost:9000',
	:outfile => 'rules.html'
}

sonarcmd = OptionParser.new do |opt|

	#help screen
	opt.banner = "Usage: sonar-rule-parser [OPTIONS] [COMMAND]"

	#individual options
	opt.on("-s","--sonar SONAR","sonarqube server instance") do |sonar|
		begin 
			url = URI.parse(sonar)
			req = Net::HTTP.new(url.host, url.port)
			status = req.request_head(url.path).code.to_i
		rescue Exception => e
			puts "Error occurred while accessing input url: #{e.message}"
		end
		abort("Input URL #{sonar} could not be resolved to a SonarQube instance") unless status && status >= 200 && status < 400
		opts[:sonar] = sonar.chomp('/')
	end

	opt.on("-p", "--pagesize PAGESIZE", "Number of rules returned") do |pagesize|
		abort "Input pagesize #{pagesize} is not an Integer" unless (Integer(pagesize) rescue false)
		opts[:ps] = pagesize
	end

	opt.on('-l', '--language LANGUAGE', "Language to query") do |language|
		opts[:language] = language
	end

	opt.on('-q', '--qprofile QUALITY_PROFILE', "Quality Profile to query") do |qprofile|
		opts[:qprofile] = qprofile
		opts[:activation] = true
	end

	opt.on('-o', '--outfile FILENAME', 'Output filename') do |outfile|
		opts[:outfile] = outfile
	end

	opt.on("-h","--help","help") do
		puts sonarcmd
		exit 0
	end
end

sonarcmd.parse!

def write_style file
	file.write <<-EOS
	<style>
		.table {
			display: table;
			border-collapse: collapse;	
			border: 1px solid black;
			font-family: Roboto, 'Helvetica Neue', Helvetica, Arial, sans-serif;
		}
		.row {
			display: table-row;
			width: 100%;
		}
		.cell {
			display: table-cell;
			vertical-align: middle;
			border: 1px solid black;
			padding: 0.5rem;
		}
		.heading {
			font-weight: 700;
			font-size: 2rem;
		}
		.param-block {
			margin: 0 0 -1em 0;
			padding: 0
		}
		.params {
			font-weight: 500;
			vertical-align: middle;
			padding: 0.5rem 1rem 0 0;
		}

		.table h2 {
			font-weight: 400;
			font-size: 1.2rem;
			line-height: 1.2rem;
			margin-bttom: 0;
			margin-top: 0.5rem;
		}

		.table pre, .param {
			display: inline-block;
			border: 1px dashed #aaa;
			box-sizing: border-box;
			margin: 0.5rem 0;
			padding: 0.5rem;
			font-family: Consolas,Menlo,Courier,monospace;
			font-size: 0.7rem;
		}
	</style>
	EOS
end

def write_heading file
	file.write "\n<div class=\"row\">"
	write_heading_text file, 'Name'
	write_heading_text file, 'Severity'
	write_heading_text file, 'Description'
	write_heading_text file, 'Tech Debt Type'
	write_heading_text file, 'Time To Fix'
	file.write '</div>'
end

def write_heading_text file, text
	file.write "<div class=\"cell heading\">#{text}</div>"
end	

def write_rule file, rule
	file.write "\n<div class=\"row\">"

	param_desc = get_param_text rule

	write_text file, rule['name'] + (param_desc || '')
	write_text file, rule['severity']
	write_text file, rule['htmlDesc']
	write_text file, rule['debtCharName']
	write_text file, rule['debtRemFnCoeff']
	file.write '</div>'
end

def get_param_text rule
	return nil if rule['params'].empty?
	param = rule['params'][0]
	return "<div class=\"params\">Params:</div><div class=\"param\">#{param['htmlDesc']} : #{param['defaultValue']}</div>"
end

def write_text file, text
	file.write "<div class=\"cell\">#{text}</div>"
end	

outfile = opts.delete(:outfile)
url = opts.delete(:sonar) + '/api/rules/search'
url += '?' + opts.map {|key, val| "#{key}=#{val}" }.join('&') unless opts.empty?

puts "Making HTTP Request to endpiont #{url}"

uri = URI.parse(url)
response = Net::HTTP.get_response(uri)

data = JSON.parse(response.body)

puts "total #{data['total']}"

File.open(outfile, 'w') { |file|
	file.write '<html><head>'
	write_style file
	file.write'</head><body>'
	file.write '<div class="table">'
	write_heading file
	for rh in data['rules'].sort {|a, b| STATUS_CODES[b['severity']] <=> STATUS_CODES[a['severity']] }
		write_rule file, rh
	end
	file.write '</div>'
	file.write "\n</body></html>"
}

