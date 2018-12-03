# Ported from:
# https://github.com/chef-cookbooks/runit/blob/v1.5.8/libraries/resource_runit_service.rb
module ::MItamae
  module Plugin
    module Resource
      class RunitService < ::MItamae::Resource::Base
        define_attribute :action, default: :enable
        define_attribute :service_name, type: String, default_name: true
        define_attribute :default_logger, type: [TrueClass, FalseClass], default: false
        define_attribute :env, type: Hash, default: {}
        define_attribute :options, type: Hash, default: {}
        define_attribute :log_size, type: Integer
        define_attribute :log_num, type: Integer
        define_attribute :templates_dir, type: String, required: true
        define_attribute :restart_on_update, type: [TrueClass, FalseClass], default: true

        define_attribute :sv_bin, type: String, default: '/usr/bin/sv'
        define_attribute :sv_dir, type: String, default: '/etc/sv'
        define_attribute :sv_verbose, type: [TrueClass, FalseClass], default: false
        define_attribute :sv_timeout, type: Integer
        define_attribute :sv_templates, type: [TrueClass, FalseClass], default: true
        define_attribute :service_dir, type: String, default: '/etc/service'
        define_attribute :run_template_name, type: String
        define_attribute :log, type: [TrueClass, FalseClass], default: true
        define_attribute :log_min, type: Integer
        define_attribute :log_timeout, type: Integer
        define_attribute :log_processor, type: String
        define_attribute :log_socket, type: [String, Hash]
        define_attribute :log_prefix, type: String
        define_attribute :log_config_append, type: String
        define_attribute :check, type: [TrueClass, FalseClass], default: false
        define_attribute :finish, type: [TrueClass, FalseClass], default: false
        define_attribute :control, type: Array, default: []
        define_attribute :control_template_names, type: Hash, default: {}
        define_attribute :lsb_init_dir, type: String, default: '/etc/init.d'

        self.available_actions = [:enable, :hup, :term]

        private

        def process_attributes
          super

          # Depends on :default_name of service_name
          unless @attributes.key?(:run_template_name)
            @attributes[:run_template_name] = @attributes.fetch(:service_name)
          end

          # Depends on :default of sv_dir
          unless @attributes[:env].empty?
            @attributes[:options].merge!(env_dir: ::File.join(@attributes.fetch(:sv_dir), @attributes.fetch(:service_name), 'env'))
          end
        end
      end
    end
  end
end
