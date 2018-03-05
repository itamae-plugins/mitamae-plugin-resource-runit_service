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
        define_attribute :options, type: Hash, default: {} # TODO: dynamic default
        define_attribute :log_dir, type: String # TODO: dynamic default, or validate
        define_attribute :log_size, type: Integer
        define_attribute :log_num, type: Integer

        define_attribute :sv_bin, type: String, default: '/usr/bin/sv'
        define_attribute :sv_verbose, type: [TrueClass, FalseClass], default: false
        define_attribute :sv_timeout, type: Integer
        define_attribute :service_dir, type: String, default: '/etc/service'

        self.available_actions = [:enable, :hup]
      end
    end
  end
end
