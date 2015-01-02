# https://github.com/jetthoughts/j-cap-recipes/blob/be9dffe279b7bee816c9bafcb3633109096b20d5/lib/sshkit/backends/ssh_command.rb
module SSHKit

  module Backend

    class SshCommand < Printer

      def run
        instance_exec(host, &@block)
      end

      def within(directory, &block)
        (@pwd ||= []).push directory.to_s
        yield
      ensure
        @pwd.pop
      end

      def execute(*args, &block)
        host_url = String(host.hostname)
        host_url = '%s@%s' % [host.username, host_url] if host.username
        result = 'ssh %s -t "%s"' % [host_url, command(*args).to_command]
        output << Command.new(result, host: host)
        system(result)
      end

    end
  end
end
