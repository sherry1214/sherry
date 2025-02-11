# frozen_string_literal: true

require 'oj'

module RemoteDevelopment
  module Settings
    class EnvVarReader
      include Messages

      REQUIRED_ENV_VAR_PREFIX = "GITLAB_REMOTE_DEVELOPMENT"

      # @param [Hash] context
      # @return [Result]
      def self.read(context)
        err_result = nil
        context[:settings].each_key do |setting_name|
          env_var_name = "#{REQUIRED_ENV_VAR_PREFIX}_#{setting_name.to_s.upcase}"
          env_var_value_string = ENV[env_var_name]

          # If there is no matching ENV var, break the loop and go to the next setting
          next unless env_var_value_string

          begin
            env_var_value = cast_value(
              env_var_name: env_var_name,
              env_var_value_string: env_var_value_string,
              setting_type: context[:setting_types][setting_name]
            )
          rescue RuntimeError => e
            # err_result will be set to a non-nil Result.err if casting fails
            err_result = Result.err(SettingsEnvironmentVariableReadFailed.new(details: e.message))
          end

          # ENV var matches an existing setting and is of the correct type, use its value to override the default value
          context[:settings][setting_name] = env_var_value
        end

        return err_result if err_result

        Result.ok(context)
      end

      # @param [String] env_var_name
      # @param [String] env_var_value_string
      # @param [Class] setting_type
      # @return [Object]
      # @raise [RuntimeError]
      def self.cast_value(env_var_name:, env_var_value_string:, setting_type:)
        # noinspection RubyIfCanBeCaseInspection -- This cannot be a case statement - see discussion here https://gitlab.com/gitlab-org/gitlab/-/merge_requests/148287#note_1849160293
        if setting_type == String
          env_var_value_string
        elsif setting_type == Integer
          # NOTE: The following line works because String#to_i does not raise exceptions for non-integer values
          unless env_var_value_string.to_i.to_s == env_var_value_string
            raise "ENV var '#{env_var_name}' value could not be cast to #{setting_type} type."
          end

          env_var_value_string.to_i
        elsif setting_type == Hash
          # NOTE: A Hash type is expected to be represented in an ENV var as a valid JSON string
          parsed_value = parse_json(env_var_name: env_var_name, value: env_var_value_string.to_s)

          unless parsed_value.is_a?(Hash)
            raise "ENV var '#{env_var_name}' was a JSON array type, but it should be an object type"
          end

          parsed_value
        elsif setting_type == Array
          # NOTE: An Array type is expected to be represented in an ENV var as a valid JSON string
          parsed_value = parse_json(env_var_name: env_var_name, value: env_var_value_string.to_s)

          unless parsed_value.is_a?(Array)
            raise "ENV var '#{env_var_name}' was a JSON object type, but it should be an array type"
          end

          parsed_value
        else
          raise "Unsupported Remote Development setting type: #{setting_type}"
        end
      end

      # @param [String] env_var_name
      # @param [String] context
      # @return [Object, Array]
      # @raise [EncodingError]
      def self.parse_json(env_var_name:, value:)
        # noinspection InvalidCallToProtectedPrivateMethod - See https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/code-inspection/why-are-there-noinspection-comments/
        Oj.load(value, mode: :rails, symbol_keys: true)
      rescue EncodingError => e
        raise "ENV var '#{env_var_name}' value was not valid parseable JSON. Parse error was: '#{e.message}'"
      end

      private_class_method :cast_value, :parse_json
    end
  end
end
