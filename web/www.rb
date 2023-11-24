require 'rubygems'
require 'bundler/setup'

require 'base64'
require 'json'
require 'uri'
require 'digest'
require 'optparse'

require './fox_utils.rb'

OPT = {}
parser = OptionParser.new { |psr|
    psr.on("-n", FalseClass) { |p| OPT[:use_nginx] = p }
    psr.on('-p port', Integer) { |p| OPT[:port] = p }
    psr.on('-r result_dir', String) { |p| OPT[:result_dir] = p }
    psr.on('-e export_dir', String) { |p| OPT[:export_dir] = p }
}

parser.parse!

require 'sinatra'
require 'sinatra/base'
require 'sinatra/support'
Bundler.require

register Sinatra::UserAgentHelpers


class FoxApp < Sinatra::Base
    if OPT.has_key?(:export_dir)
        BASE = OPT[:export_dir]
    else
        BASE = File.expand_path("~")
    end

    NGINX_PORT = 18082
    if OPT.has_key?(:result_dir)
        RESULT_DIR = OPT[:result_dir]
    else
        RESULT_DIR = "/tmp/"
    end


    def self.nginx
        @@nginx
    end

    cur_dir = BASE

    configure do
        if OPT.has_key?(:port)
            set :port, OPT[:port]
        else
            set :port, 4567
        end

        set :public_folder, File.dirname(__FILE__) + '/public'
        set :bind, '0.0.0.0'
        set :environment, :production
        set :server, %w[thin mongrel webrick]
        enable :sessions

        @@nginx = Nginx.new(RESULT_DIR, NGINX_PORT)
        if !OPT.has_key?(:use_nginx) || OPT[:use_nginx]
            @@nginx.start
        end

        #  set :show_exceptions, false
        #  mime_type :avi, "video/mpeg"
    end

    convert = {
        "avi" => {
            "icon" => "icon-facetime-video",
            "make_url" => Proc.new { |file_en, cur_dir, ext, ua|
                file = file_en
                if ua =~ /VLC.*LibVLC/ or ua =~ /Chrom/
                    "/file/#{Base64.urlsafe_encode64(cur_dir + '/' + file)}"
                else
                    "/convert/#{ext}/#{Base64.urlsafe_encode64(cur_dir + '/' + file)}"
                end
            },
            "proc" => Proc.new {|file_en, session, ua = ""|
                file = Base64.urlsafe_decode64(file_en).force_encoding("UTF-8")
                output_file_name = "#{RESULT_DIR}#{Digest::MD5.hexdigest(file)}"
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

                        stereo_converter = " -ac 2 "
                        cmd = "cd \"#{File.dirname(file)}\" && ffmpeg -i #{output_file_name + ".link"} -vcodec #{codec} -strict -2 -flags +aic+mv4 #{stereo_converter} -threads #{threads} #{output_file_name}"
                        puts cmd
                    else
                        cmd = "echo 'Already exists: #{file}'"
                        puts "!!! Already exists converted file: #{file} -> #{output_file_name}"
                    end

                    IO.popen(cmd) { |out|
                    }

                    "/video/#{URI.encode_www_form_component(output_file_name)}"
                else
                    output_file_name += ".avi"

                    if not File.exist?(output_file_name)
                        File.symlink(file, output_file_name)
                    else
                        puts "!!! Already exists converted file: #{file} -> #{output_file_name}"
                    end

                    "/video/#{URI.encode_www_form_component(output_file_name)}"
                end
            }
        },
        "epub" => {
            "icon" => "icon-book",
            "proc" => Proc.new {|file, session, ua = ""|
                "/file/#{URI.encode_www_form_component(file)}"
            }
        },
        "pdf" => {
            "icon" => "icon-book",
            "proc" => Proc.new {|file, session, ua = ""|
                "/file/#{URI.encode_www_form_component(file)}"
            }
        },
        "djvu" => {
            "icon" => "icon-book",
            "proc" => Proc.new {|file, session, ua = ""|

                "/file/#{URI.encode_www_form_component(file)}"
            }
        },
        "mkv" => {
            "icon" => "icon-facetime-video",
            "proc" => Proc.new {|file_en, session, ua = ""|
                file = Base64.urlsafe_decode64(file_en).force_encoding("UTF-8")
                output_file_name = "#{RESULT_DIR}#{Digest::MD5.hexdigest(file)}"
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

                        resolution = ""
                        cmd = "ffprobe -v error -show_streams -select_streams v -print_format json -i \"#{output_file_name + ".link"}\" "
                        IO.popen(cmd) { |info|
                            j = info.read
                            begin
                                parsed = JSON.parse(j)
                                if parsed["streams"][0]["width"] > 1024 or parsed["streams"][0]["height"] > 768
                                    resolution = " -vf scale=720x400,setsar=1:1 "
                                    codec = "mpeg4"
                                end
                            rescue
                                resolution = " -vf scale=640x380,setsar=1:1 "
                                codec = "mpeg4"
                            end
                        }

                        audio_map = 0
                        stereo_converter = ""
                        cmd = "ffprobe -v error -show_streams -select_streams a -show_entries stream_tags=language -print_format json -i \"#{output_file_name + ".link"}\" "
                        IO.popen(cmd) { |info|
                            j = info.read
                            begin
                                parsed = JSON.parse(j)
                                parsed.each_value { |s|
                                    s.each { |t|
                                        if t["tags"]["language"] == "rus"
                                            puts t["channel_layout"]
                                            if t["channel_layout"] =~ /5[.]/
                                                stereo_converter = " -ac 2 "
                                            end
                                        end
                                    }
                                }
                            rescue
                                audio_map = 0
                            end
                        }

                        audio_code = " -c:a aac "
                        if audio_map != 0
                            audio_code = " -map 0:0 -map 0:#{audio_map} " + audio_code
                        end


                        cmd = "cd \"#{File.dirname(file)}\" && ffmpeg -i \"#{output_file_name + ".link"}\" -vcodec #{codec} #{resolution} #{audio_code} #{stereo_converter} -threads #{threads} #{output_file_name}"
                        puts cmd
                    else
                        cmd = "echo 'Already exists: #{file}'"
                        puts "!!! Already exists converted file: #{file} -> #{output_file_name}"
                    end


                    IO.popen(cmd) { |out|
                    }

                    "/video/#{URI.encode_www_form_component(output_file_name)}"
                else
                    output_file_name += ".mkv"

                    if not File.exist?(output_file_name)
                        File.symlink(file, output_file_name)
                    else
                        puts "!!! Already exists converted file: #{file} -> #{output_file_name}"
                    end

                    "/video/#{URI.encode_www_form_component(output_file_name)}"
                end
            }
        },
        "mp4" => {
            "icon" => "icon-facetime-video",
            "proc" => Proc.new {|file_en, session, ua = ""|
                file = Base64.urlsafe_decode64(file_en).force_encoding("UTF-8")
                output_file_name = "#{RESULT_DIR}#{Digest::MD5.hexdigest(file)}"

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

                        resolution = ""
                        cmd = "ffprobe -v error -show_streams -select_streams v -print_format json -i \"#{output_file_name + ".link"}\" "
                        IO.popen(cmd) { |info|
                            j = info.read
                            begin
                                parsed = JSON.parse(j)
                                if parsed["streams"][0]["width"] > 1024 or parsed["streams"][0]["height"] > 768
                                    resolution = " -vf scale=720x400,setsar=1:1 "
                                    codec = "mpeg4"
                                end
                            rescue
                                resolution = " -vf scale=640x380,setsar=1:1 "
                                codec = "mpeg4"
                            end
                        }

                        audio_map = 0
                        stereo_converter = ""
                        cmd = "ffprobe -v error -show_streams -select_streams a -show_entries stream_tags=language -print_format json -i \"#{output_file_name + ".link"}\" "
                        IO.popen(cmd) { |info|
                            j = info.read
                            begin
                                parsed = JSON.parse(j)
                                parsed.each_value { |s|
                                    s.each { |t|
                                        if t["tags"]["language"] == "rus"
                                            puts t["channel_layout"]
                                            if t["channel_layout"] =~ /5[.]/
                                                stereo_converter = " -ac 2 "
                                            end
                                        end
                                    }
                                }
                            rescue
                                audio_map = 0
                            end
                        }

                        audio_code = " -c:a aac "
                        if audio_map != 0
                            audio_code = " -map 0:0 -map 0:#{audio_map} " + audio_code
                        end


                        cmd = "cd \"#{File.dirname(file)}\" && ffmpeg -i \"#{output_file_name + ".link"}\" -vcodec #{codec} #{resolution} #{audio_code} #{stereo_converter} -threads #{threads} #{output_file_name}"
                        puts cmd
                    else
                        cmd = "echo 'Already exists: #{file}'"
                        puts "!!! Already exists converted file: #{file} -> #{output_file_name}"
                    end


                    IO.popen(cmd) { |out|
                    }

                    "/video/#{URI.encode_www_form_component(output_file_name)}"
                else
                    output_file_name += ".mp4"

                    if not File.exist?(output_file_name)
                        File.symlink(file, output_file_name)
                    else
                        puts "!!! Already exists converted file: #{file} -> #{output_file_name}"
                    end

                    "/video/#{URI.encode_www_form_component(output_file_name)}"
                end
            }
        },
        "m4b" => {
            "icon" => "icon-headphones",
            "proc" => Proc.new {|file, session, ua = ""|
                                "/file/#{URI.encode_www_form_component(file)}"
            }
        },
        "mp3" => {
            "icon" => "icon-headphones",
            "proc" => Proc.new {|file, session, ua = ""|
                                "/file/#{URI.encode_www_form_component(file)}"
            }
        },
        "jpg" => {
            "icon" => "icon-picture",
            "proc" => Proc.new {|file, session, ua = ""|
                                "/file/#{URI.encode_www_form_component(file)}"
            }
        },
        "jpeg" => {
            "icon" => "icon-picture",
            "proc" => Proc.new {|file, session, ua = ""|

                "/file/#{URI.encode_www_form_component(file)}"
            }
        },
        "gif" => {
            "icon" => "icon-picture",
            "proc" => Proc.new {|file, session, ua = ""|
                                "/file/#{URI.encode_www_form_component(file)}"
            }
        },
        "png" => {
            "icon" => "icon-picture",
            "proc" => Proc.new {|file, session, ua = ""|
                                "/file/#{URI.encode_www_form_component(file)}"
            }
        },
        "html" => {
            "icon" => "icon-file",
            "proc" => Proc.new {|file, session, ua = ""|
                                "/file/#{URI.encode_www_form_component(file)}"
            }
        },
    }


    get "/list/*" do
        cur_dir = "/" + params[:splat][0]
        begin
          cur_dir = "/" + Base64.urlsafe_decode64(params[:splat][0]).force_encoding("UTF-8")
        rescue
        end
        cur_dir = File.realpath(cur_dir)

        if cur_dir == '/'
          cur_dir = BASE
        end

        top_level = cur_dir == BASE

        d = Dir.new(cur_dir)
        files = Array.new()
        i = 0
        d.each { |f|
            if f == '.'
              next
            end

            if f == '..' and top_level
              next
            end

            i += 1
            a = {"id" => "id" + i.to_s, "name_encoded" => Base64.urlsafe_encode64(cur_dir + "/" + f), "name" => cur_dir + "/" + f, "is_dir" => File.directory?(cur_dir + "/" + f)}
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

            a["share-url"] = "/file/#{Base64.urlsafe_encode64(cur_dir + '/' + f)}"
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
                        a["url"] = "/convert/#{ext}/#{Base64.urlsafe_encode64(cur_dir + '/' + f)}"
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
        redirect to("/list/#{Base64.urlsafe_encode64(BASE)}")
    end


    get '/convert/:convert/*' do |cnv, file|
        puts "UA = #{request.user_agent}"
        redirect_url = convert[cnv]["proc"].call(file, session, request.user_agent)
        puts redirect_url
        redirect to(redirect_url)
    end


    get '/video-env/*' do |file|
        erb :video, :locals => { :file_name => "/video/#{file}" }
    end

    get '/video/*' do |file_en|
        file = '/' + URI.decode_www_form_component(file_en)
        begin
          file = Base64.urlsafe_decode64(file_en).force_encoding("UTF-8")
        rescue
        end

        if @@nginx.started?
            redirect_url = "http://#{request.host}:#{@@nginx.port}#{file}"
            redirect to(redirect_url)
        else
            send_file file
        end
    end

    get '/file/*' do |file_en|
        file = URI.decode_www_form_component(file_en)
        begin
          file = Base64.urlsafe_decode64(file_en).force_encoding("UTF-8")
        rescue
        end

        ext = File.extname('/' + file)

        if ext.length > 0
            ext = ext[1..-1]
        end
        ext = convert.key(ext)

        if @@nginx.started?
            redirect_url = "http://#{request.host}:#{@@nginx.port}/" +
                           file.split("/").map { |a| a.split(" ").map { |b| URI.encode_www_form_component(b) }.join("%20") }.join("/")
            redirect redirect_url
        else
            send_file '/' + file, :length => File.stat('/' + file).size, :filename => File.basename('/' + file)
        end
    end

    get // do
        puts "CATCH request.path_info = #{request.path_info}"
        return 404
    end
end

at_exit do
    puts "SHUTTING DOWN!"
    FoxApp.nginx.stop
    exit
end

FoxApp.run!
