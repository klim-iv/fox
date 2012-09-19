require 'rubygems'
require 'sinatra'
require 'json'

enable :sessions

BASE = File.expand_path("~")

cur_dir = BASE

convert = {
  "avi" => Proc.new {|file, session|
      cmd = "cd \"#{File.dirname(file)}\" && rm -Rf /tmp/#{session[:session_id]}.mp4 && ffmpeg -i \"#{file}\" -vcodec mpeg4 -flags +aic+mv4 /tmp/#{session[:session_id]}.mp4"
      puts cmd

      redirect_url = ""
      IO.popen(cmd) { |out|
      }

      "/video/#{session[:session_id]}.mp4"
    },
}


get "/list/*" do
  cur_dir = "/" + params[:splat][0]
  d = Dir.new(cur_dir)
  files = Array.new()
  d.each { |f|
        a = {"name" => cur_dir + "/" + f, "is_dir" => File.directory?(cur_dir + "/" + f)}
        ext = f.match(/.*[.]([^.]*)$/)
        if ext != nil
          ext = ext[1]
          if not a["is_dir"] and convert.has_key?(ext)
            a["url"] = "/convert/#{ext}/#{cur_dir}/#{f}"
          end
        end
        files << a
  }

  erb :dir, :locals => { :cur_dir => cur_dir, :files => files, :session_id => session[:session_id] }
end


get '/' do
  redirect to("/list/#{BASE}")
end


get '/convert/:convert/*' do |file|
  redirect_url = convert[params[:convert]].call("/" + params[:splat][0], session)
  puts redirect_url
  redirect to(redirect_url)
end


get '/video/*' do |file|
  send_file '/tmp/' + file
end
