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
