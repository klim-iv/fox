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
#  mime_type :avi, "video/mpeg"
end

set :bind, '0.0.0.0'
enable :sessions

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
        output_file_name = "/tmp/#{Digest::MD5.hexdigest(file)}"
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
                puts "!!! Already exists converted file: #{file} -> #{output_file_name}"
            end

            redirect_url = ""
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
        output_file_name = "/tmp/#{Digest::MD5.hexdigest(file)}"
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
                puts "!!! Already exists converted file: #{file} -> #{output_file_name}"
            end


            redirect_url = ""
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