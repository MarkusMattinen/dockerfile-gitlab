# unicorn config file
worker_processes 2
working_directory "/home/git/gitlab"
listen "/home/git/gitlab/tmp/sockets/gitlab.socket", :backlog => 1024
listen "127.0.0.1:8080", :tcp_nopush => true
timeout 60
pid "/home/git/gitlab/tmp/pids/unicorn.pid"
preload_app true
GC.respond_to?(:copy_on_write_friendly=) and
  GC.copy_on_write_friendly = true
check_client_connection false

before_fork do |server, worker|
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.connection.disconnect!

  old_pid = "#{server.config[:pid]}.oldbin"
  if old_pid != server.pid
    begin
      sig = (worker.nr + 1) >= server.worker_processes ? :QUIT : :TTOU
      Process.kill(sig, File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
    end
  end
end

after_fork do |server, worker|
  defined?(ActiveRecord::Base) and
    ActiveRecord::Base.establish_connection
end
