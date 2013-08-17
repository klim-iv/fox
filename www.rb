require 'rubygems'
require 'sinatra'
require 'json'

configure do
  set :public_folder, File.dirname(__FILE__) + '/public'
end

enable :sessions

BASE = File.expand_path("~")

cur_dir = BASE

convert = {
  "avi" => {
    "icon" => "icon-facetime-video",
    "proc" => Proc.new {|file, session|
        cmd = "cd \"#{File.dirname(file)}\" && rm -Rf /tmp/#{session[:session_id]}.mp4 && ffmpeg -i \"#{file}\" -vcodec mpeg4 -flags +aic+mv4 /tmp/#{session[:session_id]}.mp4"
        puts cmd

        redirect_url = ""
        IO.popen(cmd) { |out|
        }

        "/video/#{session[:session_id]}.mp4"
      }
    },
  "pdf" => {
    "icon" => "icon-book",
    "proc" => Proc.new {|file, session|

        "/file/#{file}"
      }
    },
  "djvu" => {
    "icon" => "icon-book",
    "proc" => Proc.new {|file, session|

        "/file/#{file}"
      }
    },
  "mkv" => {
    "icon" => "icon-facetime-video",
    "proc" => Proc.new {|file, session|
        cmd = "cd \"#{File.dirname(file)}\" && rm -Rf /tmp/#{session[:session_id]}.mp4 && ffmpeg -i \"#{file}\" -vcodec copy /tmp/#{session[:session_id]}.mp4"
        puts cmd

        redirect_url = ""
        IO.popen(cmd) { |out|
        }

        "/file//tmp/#{session[:session_id]}.mp4"
      }
    },
  "mp3" => {
    "icon" => "icon-headphones",
    "proc" => Proc.new {|file, session|

        "/file/#{file}"
      }
    },
}


get "/list/*" do
  cur_dir = "/" + params[:splat][0]
  d = Dir.new(cur_dir)
  files = Array.new()
  i = 0
  d.each { |f|
        i += 1
        a = {"id" => "id" + i.to_s, "name" => cur_dir + "/" + f, "is_dir" => File.directory?(cur_dir + "/" + f)}
        if File.directory?(cur_dir + "/" + f)
          a["icon"] = "icon-folder-open"
        else
          a["icon"] = "icon-question-sign"
        end

        ext = f.match(/.*[.]([^.]*)$/)
        if ext != nil
          ext = ext[1]
          if not a["is_dir"] and convert.has_key?(ext)
            a["url"] = "/convert/#{ext}/#{cur_dir}/#{f}"

            if convert[ext].has_key?("icon")
              a["icon"] = convert[ext]["icon"]
            end
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
  redirect_url = convert[params[:convert]]["proc"].call("/" + params[:splat][0], session)
  puts redirect_url
  redirect to(redirect_url)
end


get '/video/*' do |file|
  send_file '/tmp/' + file
end

get '/file/*' do |file|
  send_file '/' + file
end
