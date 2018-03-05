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
          if desired.enabled
            action_enable
          end
          if desired.hupped
            action_hup
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
            current.enabled = false
          when :hup
            current.hupped = false
            current.running = running?
          else
            raise NotImplementedError, "unhandled action: '#{action}'"
          end
        end

        def action_enable
          puts "!!! ENABLE !!!"
        end

        # https://github.com/chef-cookbooks/runit/blob/v1.5.8/libraries/provider_runit_service.rb#L212-L218
        def action_hup
          if current.running
            runit_send_signal(:hup)
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
      end
    end
  end
end
