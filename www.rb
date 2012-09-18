require 'rubygems'
require 'sinatra'
require 'json'

convert = {
  "avi" => Proc.new {|file, session|
      puts "cd #{File.dirname(file)} && rm -Rf #{session[:session_id]}.mp4 && ffmpeg -i \"#{file}\" -vcodec mpeg4 -flags +aic+mv4 #{session[:session_id]}.mp4"
#      IO.popen("cd #{File.dirname(file)} && rm -Rf #{session[:session_id]}.mp4 && ffmpeg -i \"#{file}\" -vcodec mpeg4 -flags +aic+mv4 #{session[:session_id]}.mp4") { |out|
#        redirect to("/video/#{session[:session_id]}.mp4")
#      }
    },
}

BASE = File.expand_path("~")
enable :sessions

cur_dir = BASE

get "/list/*" do
  cur_dir = "/" + params[:splat][0]
  d = Dir.new(cur_dir)
  files = Array.new()
  d.each { |f|
        a = {"name" => cur_dir + "/" + f, "is_dir" => File.directory?(cur_dir + "/" + f)}
        puts f
        puts f.gsub(/.*[.]([^.]*)$/, '\1')
        convert.has_key?(f.gsub(/.*[.]([^.]*)$/, '\1'))
        if not a["is_dir"] && convert.has_key?(f.gsub(/.*[.]([^.]*)$/, '\1'))
          a["url"] = "/convert/#{f}"
        end
        files << a
  }

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
