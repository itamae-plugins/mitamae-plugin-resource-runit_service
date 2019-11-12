# Ported from:
# https://github.com/chef-cookbooks/runit/blob/v1.5.8/libraries/provider_runit_service.rb
module ::MItamae
  module Plugin
    module ResourceExecutor
      class RunitService < ::MItamae::ResourceExecutor::Base
        # Overriding https://github.com/itamae-kitchen/mitamae/blob/v1.5.6/mrblib/mitamae/resource_executor/base.rb#L31-L33,
        # and called at https://github.com/itamae-kitchen/mitamae/blob/v1.5.6/mrblib/mitamae/resource_executor/base.rb#L85
        # to reflect `desired` states which are not met in `current`.
        def apply
          if desired.termed
            action_term
          end
          if desired.enabled
            action_enable
          end
          if desired.hupped
            action_hup
          end
          if desired.inted
            action_int
          end
          if desired.restarted
            action_restart
          end
        end

        private

        attr_reader :release_path, :previous_release_path

        # Overriding https://github.com/itamae-kitchen/mitamae/blob/v1.5.6/mrblib/mitamae/resource_executor/base.rb#L147-L149,
        # and called at https://github.com/itamae-kitchen/mitamae/blob/v1.5.6/mrblib/mitamae/resource_executor/base.rb#L67-L68
        # to map specified action (only :deploy here) to attributes to be modified. Attributes specified in recipes (:revision,
        # :repository, etc...) are already set to `desired`. So we don't need to set them manually.
        # https://github.com/itamae-kitchen/mitamae/blob/v1.5.6/mrblib/mitamae/resource_executor/base.rb#L142.
        #
        # Difference between `desired` and `current` are aimed to be changed in #apply.
        def set_desired_attributes(desired, action)
          case action
          when :enable
            desired.enabled = true
          when :hup
            desired.hupped = true
          when :int
            desired.inted = true
          when :term
            desired.termed = true
          when :restart
            desired.restarted = true
          when :nothing
            # nothing
          else
            raise NotImplementedError, "unhandled action: '#{action}'"
          end
        end

        # Overriding https://github.com/itamae-kitchen/mitamae/blob/v1.5.6/mrblib/mitamae/resource_executor/base.rb#L135-L137,
        # and called at https://github.com/itamae-kitchen/mitamae/blob/v1.5.6/mrblib/mitamae/resource_executor/base.rb#L70-L71
        # to map the current machine status to attributes. Probably similar to Chef's #load_current_resource.
        #
        # current_attributes which are the same as desired_attributes will NOT be touched in #apply.
        def set_current_attributes(current, action)
          case action
          when :enable
            current.enabled = enabled?
          when :hup
            current.hupped = false
            current.running = running?
          when :int
            current.inted = false
            current.running = running?
          when :term
            current.termed = false
            current.running = running?
          when :restart
            current.restarted = false
          when :nothing
            # nothing
          else
            raise NotImplementedError, "unhandled action: '#{action}'"
          end
        end

        # https://github.com/chef/chef/blob/v12.13.37/lib/chef/provider/service.rb#L165-L172
        def action_restart
          restart_service
          MItamae.logger.info("#{log_prefix} restarted")
        end

        # https://github.com/chef-cookbooks/runit/blob/v1.5.8/libraries/provider_runit_service.rb#L156-L173
        def action_enable
          configure_service # Do this every run, even if service is already enabled and running
          MItamae.logger.info("#{log_prefix} configured")
          if current.enabled
            MItamae.logger.debug("#{log_prefix} already enabled - nothing to do")
          else
            enable_service
            MItamae.logger.info("#{log_prefix} enabled")
          end
          restart_service if desired.restart_on_update && run_script.updated_by_last_action?
          restart_log_service if desired.restart_on_update && log_run_script.updated_by_last_action?
          restart_log_service if desired.restart_on_update && log_config_file.updated_by_last_action?
        end

        def configure_service
          if desired.sv_templates
            MItamae.logger.debug("Creating sv_dir for #{desired.service_name}")
            run_child(sv_dir, :create)
            MItamae.logger.debug("Creating run_script for #{desired.service_name}")
            run_child(run_script, :create)

            if desired.log
              MItamae.logger.debug("Setting up svlog for #{desired.service_name}")
              run_child(log_dir, :create)
              run_child(log_main_dir, :create)
              run_child(default_log_dir, :create) if desired.default_logger
              run_child(log_run_script, :create)
              run_child(log_config_file, :create)
            else
              MItamae.logger.debug("log not specified for #{desired.service_name}, continuing")
            end

            unless desired.env.empty?
              MItamae.logger.debug("Setting up environment files for #{desired.service_name}")
              run_child(env_dir, :create)
              env_files.each { |file| run_child(file, :create) }
            else
              MItamae.logger.debug("Environment not specified for #{desired.service_name}, continuing")
            end

            if desired.check
              MItamae.logger.debug("Creating check script for #{desired.service_name}")
              run_child(check_script, :create)
            else
              MItamae.logger.debug("Check script not specified for #{desired.service_name}, continuing")
            end

            if desired.finish
              MItamae.logger.debug("Creating finish script for #{desired.service_name}")
              run_child(finish_script, :create)
            else
              MItamae.logger.debug("Finish script not specified for #{desired.service_name}, continuing")
            end

            unless desired.control.empty?
              MItamae.logger.debug("Creating control signal scripts for #{desired.service_name}")
              run_child(control_dir, :create)
              control_signal_files.each { |file| run_child(file, :create) }
            else
              MItamae.logger.debug("Control signals not specified for #{desired.service_name}, continuing")
            end
          end

          MItamae.logger.debug("Creating lsb_init compatible interface #{desired.service_name}")
          run_child(lsb_init, :create)
        end

        def enable_service
          MItamae.logger.debug("Creating symlink in service_dir for #{desired.service_name}")
          run_child(service_link, :create)
          run_child(log_config_link, :create)

          MItamae.logger.debug("waiting until named pipe #{service_dir_name}/supervise/ok exists.")
          until ::FileTest.pipe?("#{service_dir_name}/supervise/ok")
            sleep 1
            MItamae.logger.debug('.')
          end

          if desired.log
            MItamae.logger.debug("waiting until named pipe #{service_dir_name}/log/supervise/ok exists.")
            until ::FileTest.pipe?("#{service_dir_name}/log/supervise/ok")
              sleep 1
              MItamae.logger.debug('.')
            end
          end
        end

        def restart_service
          @runner.run_command("#{desired.sv_bin} #{sv_args}restart #{service_dir_name}")
        end

        def restart_log_service
          @runner.run_command("#{desired.sv_bin} #{sv_args}restart #{service_dir_name}/log")
        end

        # https://github.com/chef-cookbooks/runit/blob/v1.5.8/libraries/provider_runit_service.rb#L212-L218
        def action_hup
          if current.running
            runit_send_signal(:hup)
          else
            MItamae.logger.debug("#{log_prefix} not running - nothing to do")
          end
        end

        # https://github.com/chef-cookbooks/runit/blob/v1.5.8/libraries/provider_runit_service.rb#L212-L218
        def action_int
          if current.running
            runit_send_signal(:int)
          else
            MItamae.logger.debug("#{log_prefix} not running - nothing to do")
          end
        end

        # https://github.com/chef-cookbooks/runit/blob/v1.5.8/libraries/provider_runit_service.rb#L212-L218
        def action_term
          if current.running
            runit_send_signal(:term)
          else
            MItamae.logger.debug("#{log_prefix} not running - nothing to do")
          end
        end

        def runit_send_signal(signal, friendly_name = nil)
          friendly_name ||= signal
          @runner.run_command("#{desired.sv_bin} #{sv_args}#{signal} #{service_dir_name}")
          MItamae.logger.info("#{log_prefix} sent #{friendly_name}")
        end

        def running?
          cmd = @runner.run_command("#{desired.sv_bin} #{sv_args}status #{service_dir_name}", error: false)
          (cmd.stdout =~ /^run:/ && cmd.exit_status == 0)
        end

        def enabled?
          ::File.exists?(::File.join(service_dir_name, 'run'))
        end

        def sv_dir_name
          ::File.join(desired.sv_dir, desired.service_name)
        end

        def sv_args
          sv_args = ''
          sv_args += "-w '#{desired.sv_timeout}' " unless desired.sv_timeout.nil?
          sv_args += '-v ' if desired.sv_verbose
          sv_args
        end

        def service_dir_name
          ::File.join(desired.service_dir, desired.service_name)
        end

        def log_prefix
          "runit_service[#{desired.service_name}]"
        end

        def default_logger_content
          "#!/bin/sh
exec svlogd -tt /var/log/#{desired.service_name}"
        end

        #
        # Helper Resources
        #
        def sv_dir
          @sv_dir ||= with_new_recipe do |recipe|
            MItamae::Resource::Directory.new(sv_dir_name, recipe, desired: desired) do
              owner desired.owner
              group desired.group
              mode '755'
            end
          end
        end

        def run_script
          @run_script ||= with_new_recipe do |recipe|
            MItamae::Resource::Template.new(::File.join(sv_dir_name, 'run'), recipe, desired: desired) do
              owner desired.owner
              group desired.group
              source ::File.expand_path("sv-#{desired.run_template_name}-run.erb", desired.templates_dir)
              mode '755'
              variables(options: desired.options)
            end
          end
        end

        def log_dir
          @log_dir ||= with_new_recipe do |recipe|
            MItamae::Resource::Directory.new(::File.join(sv_dir_name, 'log'), recipe, desired: desired) do
              owner desired.owner
              group desired.group
              mode '755'
            end
          end
        end

        def log_main_dir
          @log_main_dir ||= with_new_recipe do |recipe|
            MItamae::Resource::Directory.new(::File.join(sv_dir_name, 'log', 'main'), recipe, desired: desired) do
              owner desired.woner
              group desired.group
              mode '755'
            end
          end
        end

        def default_log_dir
          @default_log_dir ||= with_new_recipe do |recipe|
            MItamae::Resource::Directory.new(::File.join("/var/log/#{desired.service_name}"), recipe, desired: desired) do
              owner desired.owner
              group desired.group
              mode '755'
            end
          end
        end

        def log_run_script
          return @log_run_script unless @log_run_script.nil?
          if desired.default_logger
            @log_run_script = with_new_recipe do |recipe|
              MItamae::Resource::File.new(::File.join(sv_dir_name, 'log', 'run'), recipe, desired: desired, default_logger_content: default_logger_content) do
                content default_logger_content
                owner desired.owner
                group desired.group
                mode '755'
              end
            end
          else
            @log_run_script = with_new_recipe do |recipe|
              MItamae::Resource::Template.new(::File.join(sv_dir_name, 'log', 'run'), recipe, desired: desired) do
                owner desired.owner
                group desired.group
                mode '755'
                source ::File.expand_path("sv-#{desired.log_template_name}-log-run.erb", desired.templates_dir)
                variables(options: desired.options)
              end
            end
          end
        end

        def log_config_file
          @log_config_file ||= with_new_recipe do |recipe|
            MItamae::Resource::Template.new(::File.join(sv_dir_name, 'log', 'config'), recipe, desired: desired, __dir__: __dir__) do
              owner desired.owner
              group desired.group
              mode '644'
              source ::File.expand_path('templates/log-config.erb', __dir__)
              variables(
                size: desired.log_size,
                num: desired.log_num,
                min: desired.log_min,
                timeout: desired.log_timeout,
                processor: desired.log_processor,
                socket: desired.log_socket,
                prefix: desired.log_prefix,
                append: desired.log_config_append
              )
            end
          end
        end

        def env_dir
          @env_dir ||= with_new_recipe do |recipe|
            MItamae::Resource::Directory.new(::File.join(sv_dir_name, 'env'), recipe, desired: desired) do
              owner desired.owner
              group desired.group
              mode '755'
            end
          end
        end

        def env_files
          @env_files ||= with_new_recipe do |recipe|
            desired.env.map do |var, value|
              MItamae::Resource::File.new(::File.join(sv_dir_name, 'env', var), recipe, desired: desired) do
                owner desired.owner
                group desired.group
                content value
              end
            end
          end
        end

        def check_script
          @check_script ||= with_new_recipe do |recipe|
            MItamae::Resource::Template.new(::File.join(sv_dir_name, 'check'), recipe, desired: desired) do
              owner desired.owner
              gropu desired.group
              source ::File.expand_path("sv-#{desired.check_script_template_name}-check.erb", desired.templates_dir)
              mode '755'
              variables(options: desired.options)
            end
          end
        end

        def finish_script
          @finish_script ||= with_new_recipe do |recipe|
            MItamae::Resource::Template.new(::File.join(sv_dir_name, 'finish'), recipe, desired: desired) do
              owner desired.owner
              gropu desired.group
              mode '755'
              source ::File.expand_path("sv-#{desired.finish_script_template_name}-finish.erb", desired.templates_dir)
              variables(options: desired.options)
            end
          end
        end

        def control_dir
          @control_dir ||= with_new_recipe do |recipe|
            MItamae::Resource::Directory.new(::File.join(sv_dir_name, 'control'), recipe, desired: desired) do
              owner desired.owner
              group desired.group
              mode '755'
            end
          end
        end

        def control_signal_files
          @control_signal_files ||= with_new_recipe do |recipe|
            desired.control.map do |signal|
              MItamae::Resource::Template.new(::File.join(sv_dir_name, 'control', signal), recipe, desired: desired) do
                owner desired.owner
                group desired.group
                mode '755'
                source ::File.expand_path("sv-#{desired.control_template_names[signal]}-check.erb", desired.templates_dir)
                variables(options: options)
              end
            end
          end
        end

        def lsb_init
          return @lsb_init unless @lsb_init.nil?
          initfile = ::File.join(desired.lsb_init_dir, desired.service_name)
          if node[:platform] == 'debian'
            ::File.unlink(initfile) if ::File.symlink?(initfile)
            @lsb_init = with_new_recipe do |recipe|
              MItamae::Resource::Template.new(initfile, recipe, desired: desired, __dir__: __dir__) do
                owner 'root'
                group 'root'
                mode '755'
                source ::File.expand_path('templates/init.d.erb', __dir__)
                variables(name: desired.service_name)
              end
            end
          else
            @lsb_init = with_new_recipe do |recipe|
              MItamae::Resource::Link.new(initfile, recipe, desired: desired) do
                to desired.sv_bin
              end
            end
          end
          @lsb_init
        end

        def service_link
          @service_link ||= with_new_recipe do |recipe|
            MItamae::Resource::Link.new(::File.join(service_dir_name), recipe, sv_dir_name: sv_dir_name) do
              to sv_dir_name
            end
          end
        end

        def log_config_link
          @log_config_link ||= with_new_recipe do |recipe|
            MItamae::Resource::Link.new(::File.join(log_main_dir, 'config'), recipe, log_config_file: log_config_file) do
              to log_config_file
            end
          end
        end

        #
        # MItamae Helpers
        #
        def with_new_recipe(&block)
          new_recipe = MItamae::Recipe.new(@resource.recipe.path, @resource.recipe)
          block.call(new_recipe).tap do |result|
            new_recipe.children << result
          end
        end

        def run_child(resource, action)
          executor = ::MItamae::ResourceExecutor.create(resource, @runner)
          executor.execute(action)
          if executor.send(:updated?) # hack...
            def resource.updated_by_last_action?; true; end
          else
            def resource.updated_by_last_action?; false; end
          end
        end

        # __FILE__ is "(eval)". This is workaround to find template.
        def __dir__
          # MItamae plugin is only searched from relative "./plugins".
          "./plugins/mitamae-plugin-resource-runit_service/mrblib/resource_executor/"
        end

        # Workaround hack...
        def node
          @node ||= MItamae::Node.new({}, @runner.instance_variable_get(:@backend))
        end
      end
    end
  end
end
