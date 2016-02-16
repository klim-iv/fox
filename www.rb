require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/support'
require 'json'
require 'uri'
require 'digest'

require './fox_utils.rb'

Bundler.require

register Sinatra::UserAgentHelpers

configure do
  set :public_folder, File.dirname(__FILE__) + '/public'
#  set :traps, false
#  mime_type :avi, "video/mpeg"
end

set :bind, '0.0.0.0'
enable :sessions

#set :show_exceptions, false

result_dir = "/tmp/"

### BEGIN test Nginx
nginx_bin=""
nginx_cfg = []
begin
    IO.popen("which nginx").each_line { |out|
        nginx_bin = out.strip
    }
rescue
end

if nginx_bin.length > 0
    nginx_cfg_str = ""
    IO.popen([nginx_bin, "-V", :err => [:child, :out]]).each_line { |l|
        if l =~ /configure/
            nginx_cfg_str = l
        end
    }
    nginx_cfg = nginx_cfg_str.split(/--/).map { |a|
        if a =~ /^with-/
            a.strip
        else
            ""
        end
    }.keep_if { |a|
        a.length > 0
    }
end

if nginx_cfg.find_index { |a|
        a =~ /.*mp4_module.*/
    } != nil
    puts "Exists MP4 support in Nginx"

    cfg = File.new("nginx_local.conf", "w", 0644)
    cfg.write <<-NGINX_CFG.undent
        events {
            worker_connections 8;
        }

        http {
            server {
                listen 18081;

                root /;
                index index.html;

                location #{result_dir} {
                    mp4;
                    mp4_buffer_size     1m;
                    mp4_max_buffer_size 5m;
                }
            }
        }
    NGINX_CFG
    cfg.close

    pid = spawn("#{nginx_bin} -c #{Dir.getwd}/nginx_local.conf")

    trap("TERM") do
        puts "Terminating..."
        pid = spawn("#{nginx_bin} -s stop")
    end
else
    puts "No support MP4 in Nginx"
end
### END test Nginx


BASE = File.expand_path("~")

cur_dir = BASE

convert = {
  "avi" => {
    "icon" => "icon-facetime-video",
    "make_url" => Proc.new { |file_en, cur_dir, ext, ua|
        file = URI.encode_www_form_component(file_en)
        if ua =~ /VLC.*LibVLC/ or ua =~ /Chromium/
            "/file/#{URI.encode(cur_dir + '/' + file)}"
        else
            "/convert/#{ext}/#{URI.encode(cur_dir + '/' + file)}"
        end
    },
    "proc" => Proc.new {|file_en, session, ua = ""|
        file = URI.decode(file_en)
        output_file_name = "#{result_dir}#{Digest::MD5.hexdigest(file)}"
        a = UserAgent.new ua
        if a.ipad?
            output_file_name += ".mp4"

            codec = "mpeg4"
            threads = processor_count

            if not File.exist?(output_file_name)
                begin
                    File.delete(output_file_name + ".link")
                rescue
                end

                begin
                    File.symlink(file, output_file_name + ".link")
                rescue
                end

                cmd = "cd \"#{File.dirname(file)}\" && ffmpeg -i #{output_file_name + ".link"} -vcodec #{codec} -strict -2 -flags +aic+mv4 -threads #{threads} #{output_file_name}"
                puts cmd
            else
                cmd = "echo 'Already exists: #{file}'"
                puts "!!! Already exists converted file: #{file} -> #{output_file_name}"
            end

            IO.popen(cmd) { |out|
            }

            "/video/#{URI.encode(output_file_name)}"
        else
            output_file_name += ".avi"

            if not File.exist?(output_file_name)
                File.symlink(file, output_file_name)
            else
                puts "!!! Already exists converted file: #{file} -> #{output_file_name}"
            end

            "/video/#{URI.encode(output_file_name)}"
        end
      }
    },
  "pdf" => {
    "icon" => "icon-book",
    "proc" => Proc.new {|file, session, ua = ""|
        "/file/#{URI.encode(file)}"
      }
    },
  "djvu" => {
    "icon" => "icon-book",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{URI.encode(file)}"
      }
    },
  "mkv" => {
    "icon" => "icon-facetime-video",
    "proc" => Proc.new {|file_en, session, ua = ""|
        file = URI.decode(file_en)
        output_file_name = "#{result_dir}#{Digest::MD5.hexdigest(file)}"
        a = UserAgent.new ua
        if a.ipad?
            output_file_name += ".mp4"

            cmd = "ffprobe \"#{file}\" 2>&1"
            codec = "mpeg4"
            IO.popen(cmd).each_line { |line|
                if line =~ /Stream .*:.*Video: .264/
                   codec = "copy"
                end
            }
            threads = processor_count

            if not File.exist?(output_file_name)
                begin
                    File.delete(output_file_name + ".link")
                rescue
                end

                begin
                    File.symlink(file, output_file_name + ".link")
                rescue
                end

                cmd = "cd \"#{File.dirname(file)}\" && ffmpeg -i \"#{output_file_name + ".link"}\" -vcodec #{codec} -acodec copy -threads #{threads} #{output_file_name}"
                puts cmd
            else
                cmd = "echo 'Already exists: #{file}'"
                puts "!!! Already exists converted file: #{file} -> #{output_file_name}"
            end


            IO.popen(cmd) { |out|
            }

            "/video/#{URI.encode(output_file_name)}"
        else
            output_file_name += ".mkv"

            if not File.exist?(output_file_name)
                File.symlink(file, output_file_name)
            else
                puts "!!! Already exists converted file: #{file} -> #{output_file_name}"
            end

            "/video/#{URI.encode(output_file_name)}"
        end
      }
    },
  "mp4" => {
    "icon" => "icon-facetime-video",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{URI.encode(file)}"
      }
    },
  "mp3" => {
    "icon" => "icon-headphones",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{URI.encode(file)}"
      }
    },
  "jpg" => {
    "icon" => "icon-picture",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{URI.encode(file)}"
      }
    },
  "jpeg" => {
    "icon" => "icon-picture",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{URI.encode(file)}"
      }
    },
  "gif" => {
    "icon" => "icon-picture",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{URI.encode(file)}"
      }
    },
  "png" => {
    "icon" => "icon-picture",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{URI.encode(file)}"
      }
    },
  "html" => {
    "icon" => "icon-file",
    "proc" => Proc.new {|file, session, ua = ""|

        "/file/#{URI.encode(file)}"
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

        a["share-url"] = "/file/#{URI.encode(cur_dir + '/' + f)}"
        if File.directory?(cur_dir + "/" + f)
          a["icon"] = "icon-folder-open"
          a["share-url"] = ""
        else
          a["icon"] = "icon-question-sign"
        end

        ext = f.match(/.*[.]([^.]*)$/)
        if ext != nil
          ext = ext[1]
          if not a["is_dir"] and convert.has_key?(ext)
            if convert[ext].has_key?("make_url")
              a["url"] = convert[ext]["make_url"].call(f, cur_dir, ext, request.user_agent)
            else
              a["url"] = "/convert/#{ext}/#{URI.encode(cur_dir + '/' + f)}"
            end

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

get '/video/*' do |file_en|
  file = '/' + URI.decode(file_en)

  send_file file
end

get '/file/*' do |file_en|
  file = URI.decode(file_en)

  ext = File.extname('/' + file)

  if ext.length > 0
    ext = ext[1..-1]
  end
  ext = convert.key(ext)

  send_file '/' + file, :length => File.stat('/' + file).size, :filename => File.basename('/' + file)
end

get // do
  puts "CATCH request.path_info = #{request.path_info}"
  return 404
end
