require 'rubygems'
require 'sinatra'
require 'json'

BASE = File.expand_path("~")
enable :sessions

cur_dir = BASE

get "/list" do
  d = Dir.new(cur_dir)
  files = Array.new()

  d.each { |f|
      if f =~ /.*t.*/
          files << f
      end
  }
  puts JSON.dump(session)
  erb :dir, :locals => { :cur_dir => cur_dir, :files => files, :session_id => session[:session_id] }
end

get '/' do
  home = Dir.new(BASE)
  code = "<ol>"
  home.each { |f|
      if f =~ /.*avi$/
          code += "<li><a href=\"convert/#{f}\" />#{f}</video></li>"
      end
  }
  code += "</ol>"
  home.close

  code
end


get '/convert/*' do |file|
  code = ""
  if file =~ /.*avi$/
      cBASE = BASE.gsub(/[ ]/, '\ ')
      IO.popen("cd #{cBASE} && rm -Rf output.mp4 && ffmpeg -i \"#{file}\" -vcodec mpeg4 -flags +aic+mv4 output.mp4") { |out|
        #code += "<li><video controls=\"controls\" type=\"video/mpeg\" preload=\"none\"><source  src=\"video/output.mp4\" /></video></li>"
        redirect to('/video/output.mp4')
      }
  end
end


get '/video/*' do |file|
  send_file BASE + '/' + file
end
