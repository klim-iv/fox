def processor_count
    @processor_count ||= case RbConfig::CONFIG['host_os']
    when /darwin9/
        `hwprefs cpu_count`.to_i
    when /darwin/
        (`sysctl -n hw.ncpu`).to_i
    when /linux|cygwin/
        `grep -c ^processor /proc/cpuinfo`.to_i
    when /(net|open|free)bsd/
        `sysctl -n hw.ncpu`.to_i
    when /mswin|mingw/
        require 'win32ole'
        wmi = WIN32OLE.connect("winmgmts://")
        cpu = wmi.ExecQuery("select NumberOfLogicalProcessors from Win32_Processor")
        cpu.to_enum.first.NumberOfLogicalProcessors
    when /solaris2/
        `psrinfo -p`.to_i # this is physical cpus afaik
    else
        $stderr.puts "Unknown architecture ( #{RbConfig::CONFIG["host_os"]} ) assuming one processor."
        1
    end
end

class String
    def undent
        gsub(/^[ \t]{#{(slice(/^[ \t]+/) || '').length}}/, "")
    end
end


class Nginx

    attr_accessor :nginx_bin
    attr_accessor :nginx_cfg
    attr_accessor :result_dir
    attr_accessor :port
    attr_accessor :pid

    def initialize(result_dir, port)
        @nginx_bin = ""
        @nginx_cfg = []
        @result_dir = result_dir
        @port = port
        @nginx_working_dir = "/tmp/nginx-work-dir-"

        begin
            p = IO.popen("which nginx").each_line { |out|
                @nginx_bin = out.strip
            }
            p.close
        rescue
        end

        if @nginx_bin.length > 0
            nginx_cfg_str = ""
            p = IO.popen([@nginx_bin, "-V", :err => [:child, :out]]).each_line { |l|
                if l =~ /configure/
                    nginx_cfg_str = l
                end
            }
            @nginx_cfg = nginx_cfg_str.split(/--/).map { |a|
                if a =~ /^with-/
                    a.strip
                else
                    ""
                end
                }.keep_if { |a|
                a.length > 0
            }
            p.close
            @nginx_working_dir += "#{@port}"
            if !Dir.exist?(@nginx_working_dir)
                Dir.mkdir(@nginx_working_dir)
            end
        end
    end

    def start
        if @nginx_cfg.find_index { |a|
            a =~ /.*mp4_module.*/
        } != nil
            puts "Exists MP4 support in Nginx"

            cfg = File.new("#{@nginx_working_dir}/nginx-local-#{@port}.conf", "w+", 0644)
            cfg.write <<-NGINX_CFG.undent
                pid #{@nginx_working_dir}/#{@port}.pid;
                error_log #{@nginx_working_dir}/nginx_error_#{port}.log debug;
                events {
                    worker_connections 8;
                }

                http {
                    proxy_max_temp_file_size 0;
                    proxy_buffering off;
                    server {
                        listen #{@port};
                        server_name _;
                        access_log #{@nginx_working_dir}/nginx_access_#{port}.log;

                        root /;
                        index no-index.html;

                        location / {
                            mp4;
                            mp4_buffer_size     1m;
                            mp4_max_buffer_size 5m;
                        }

                        location #{@result_dir} {
                            autoindex on;
                            mp4;
                            mp4_buffer_size     1m;
                            mp4_max_buffer_size 5m;
                        }
                    }
                }
            NGINX_CFG
            cfg.close

            @pid = spawn("mkdir -p #{@nginx_working_dir}/nginx-local/logs && #{@nginx_bin} -p #{@nginx_working_dir}/nginx-local -c #{@nginx_working_dir}/nginx-local-#{@port}.conf")
        else
            puts "No support MP4 in Nginx, Nginx will not start"
            puts "For using Nginx, compile it from: http://hg.nginx.org/nginx/branches with flag: '--with-http_mp4_module'"
            puts "Build guide here: http://nginx.org/en/docs/configure.html"
        end

        return @pid
    end

    def stop
        if started?
            spawn("#{@nginx_bin} -s stop -c #{@nginx_working_dir}/nginx-local-#{@port}.conf")
            puts "Nginx stoped"
        end
    end

    def started?
        if @pid != nil
            begin
                Process.kill 0, @pid
                true
            rescue
                false
            end
        else
            false
        end
    end

end

