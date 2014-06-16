require 'rubygems'
require 'sinatra'
require 'sinatra/support'
require 'json'
require './fox_utils.rb'

register Sinatra::UserAgentHelpers

configure do
  set :public_folder, File.dirname(__FILE__) + '/public'
#  mime_type :avi, "video/mpeg"
end

set :bind, '0.0.0.0'
enable :sessions

BASE = File.expand_path("~")

cur_dir = BASE

convert = {
  "avi" => {
    "icon" => "icon-facetime-video",
    "proc" => Proc.new {|file, session, ua = ""|
        a = UserAgent.new ua
        if a.ipad?
            cmd = "ffprobe \"#{file}\" 2>&1"
            codec = "mpeg4"
            threads = processor_count

            cmd = "cd \"#{File.dirname(file)}\" && rm -Rf /tmp/#{session[:session_id]}.mp4 && ffmpeg -i \"#{file}\" -vcodec #{codec} -strict -2 -flags +aic+mv4 -threads #{threads} /tmp/#{session[:session_id]}.mp4"
            puts cmd

            redirect_url = ""
            IO.popen(cmd) { |out|
            }

            "/video/#{session[:session_id]}.mp4"
        else
            cmd = "cd \"#{File.dirname(file)}\" && rm -Rf /tmp/#{session[:session_id]}.avi && ln -s \"#{file}\" /tmp/#{session[:session_id]}.avi"
            puts cmd

            redirect_url = ""
            IO.popen(cmd) { |out|
            }

            "/video-env/#{session[:session_id]}.avi"
        end
      }
    },
  "pdf" => {
    "icon" => "icon-book",
    "proc" => Proc.new {|file, session, ua = ""|
        "/file/#{file}"
      }
    },
  "djvu" => {
    "icon" => "icon-book",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{file}"
      }
    },
  "mkv" => {
    "icon" => "icon-facetime-video",
    "proc" => Proc.new {|file, session, ua = ""|
        a = UserAgent.new ua
        if a.ipad?
            cmd = "ffprobe \"#{file}\" 2>&1"
            codec = "mpeg4"
            IO.popen(cmd).each_line { |line|
                if line =~ /Stream .*:.*Video: .264/
                   codec = "copy"
                end
            }
            threads = processor_count

            cmd = "cd \"#{File.dirname(file)}\" && rm -Rf /tmp/#{session[:session_id]}.mp4 && ffmpeg -i \"#{file}\" -vcodec #{codec} -acodec copy -threads #{threads} /tmp/#{session[:session_id]}.mp4"
            puts cmd

            redirect_url = ""
            IO.popen(cmd) { |out|
            }

            "/video/#{session[:session_id]}.mp4"
        else
            cmd = "cd \"#{File.dirname(file)}\" && rm -Rf /tmp/#{session[:session_id]}.avi && ln -s \"#{file}\" /tmp/#{session[:session_id]}.mkv"
            puts cmd

            redirect_url = ""
            IO.popen(cmd) { |out|
            }

            "/video-env/#{session[:session_id]}.mkv"
        end
      }
    },
  "mp3" => {
    "icon" => "icon-headphones",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{file}"
      }
    },
  "jpg" => {
    "icon" => "icon-picture",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{file}"
      }
    },
  "jpeg" => {
    "icon" => "icon-picture",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{file}"
      }
    },
  "gif" => {
    "icon" => "icon-picture",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{file}"
      }
    },
  "png" => {
    "icon" => "icon-picture",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{file}"
      }
    },
  "html" => {
    "icon" => "icon-file",
    "proc" => Proc.new {|file, session, ua = ""|

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

        #redefine operator for sort files
        def a.<=>(o)
          if self["is_dir"] == o["is_dir"]
              return self["name"] <=> o["name"]
          else
              if self["is_dir"] and not o["is_dir"]
                  return -1
              elsif not self["is_dir"] and o["is_dir"]
                  return 1
              end
          end
        end

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
  files = files.sort
  erb :dir, :locals => { :cur_dir => cur_dir, :files => files, :session_id => session[:session_id] }
end


get '/' do
  redirect to("/list/#{BASE}")
end


get '/convert/:convert/*' do |cnv, file|
  puts "UA = #{request.user_agent}"
  redirect_url = convert[cnv]["proc"].call("/" + file, session, request.user_agent)
  puts redirect_url
  redirect to(redirect_url)
end


get '/video-env/*' do |file|
  erb :video, :locals => { :file_name => "/video/#{file}" }
end

get '/video/*' do |file|
  send_file '/tmp/' + file
end

get '/file/*' do |file|
  send_file '/' + file
end
