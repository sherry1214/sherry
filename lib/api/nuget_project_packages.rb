# frozen_string_literal: true

# NuGet Package Manager Client API
#
# These API endpoints are not meant to be consumed directly by users. They are
# called by the NuGet package manager client when users run commands
# like `nuget install` or `nuget push`.
#
# This is the project level API.
module API
  class NugetProjectPackages < ::API::Base
    helpers ::API::Helpers::PackagesHelpers
    helpers ::API::Helpers::Packages::BasicAuthHelpers
    include ::API::Helpers::Authentication

    feature_category :package_registry

    PACKAGE_FILENAME = 'package.nupkg'
    SYMBOL_PACKAGE_FILENAME = 'package.snupkg'

    default_format :json

    authenticate_with do |accept|
      accept.token_types(:personal_access_token_with_username, :deploy_token_with_username, :job_token_with_username)
            .sent_through(:http_basic_auth)
    end

    rescue_from ArgumentError do |e|
      render_api_error!(e.message, 400)
    end

    after_validation do
      require_packages_enabled!
    end

    helpers do
      params :file_params do
        requires :package, type: ::API::Validations::Types::WorkhorseFile, desc: 'The package file to be published (generated by Multipart middleware)', documentation: { type: 'file' }
      end

      def project_or_group
        authorized_user_project(action: :read_package)
      end

      def snowplow_gitlab_standard_context
        { project: project_or_group, namespace: project_or_group.namespace }
      end

      def authorize_nuget_upload
        project = project_or_group
        authorize_workhorse!(
          subject: project,
          has_length: false,
          maximum_size: project.actual_limits.nuget_max_file_size
        )
      end

      def temp_file_name(symbol_package)
        return ::Packages::Nuget::TEMPORARY_SYMBOL_PACKAGE_NAME if symbol_package

        ::Packages::Nuget::TEMPORARY_PACKAGE_NAME
      end

      def file_name(symbol_package)
        return SYMBOL_PACKAGE_FILENAME if symbol_package

        PACKAGE_FILENAME
      end

      def upload_nuget_package_file(symbol_package: false)
        project = project_or_group
        authorize_upload!(project)
        bad_request!('File is too large') if project.actual_limits.exceeded?(:nuget_max_file_size, params[:package].size)

        file_params = params.merge(
          file: params[:package],
          file_name: file_name(symbol_package)
        )

        package = ::Packages::CreateTemporaryPackageService.new(
          project, current_user, declared_params.merge(build: current_authenticated_job)
        ).execute(:nuget, name: temp_file_name(symbol_package))

        package_file = ::Packages::CreatePackageFileService.new(package, file_params.merge(build: current_authenticated_job))
                                                            .execute

        yield(package) if block_given?

        ::Packages::Nuget::ExtractionWorker.perform_async(package_file.id) # rubocop:disable CodeReuse/Worker

        created!
      end

      def required_permission
        :read_package
      end
    end

    params do
      requires :id, types: [String, Integer], desc: 'The ID or URL-encoded path of the project', regexp: ::API::Concerns::Packages::NugetEndpoints::POSITIVE_INTEGER_REGEX
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      namespace ':id/packages/nuget' do
        include ::API::Concerns::Packages::NugetEndpoints

        # https://docs.microsoft.com/en-us/nuget/api/package-publish-resource
        desc 'The NuGet Package Publish endpoint' do
          detail 'This feature was introduced in GitLab 12.6'
          success code: 201
          failure [
            { code: 400, message: 'Bad Request' },
            { code: 401, message: 'Unauthorized' },
            { code: 403, message: 'Forbidden' },
            { code: 404, message: 'Not Found' }
          ]
          tags %w[nuget_packages]
        end

        params do
          use :file_params
        end
        put urgency: :low do
          upload_nuget_package_file do |package|
            track_package_event(
              'push_package',
              :nuget,
              category: 'API::NugetPackages',
              project: package.project,
              namespace: package.project.namespace
            )
          end
        rescue ObjectStorage::RemoteStoreError => e
          Gitlab::ErrorTracking.track_exception(e, extra: { file_name: params[:file_name], project_id: project_or_group.id })

          forbidden!
        end

        desc 'The NuGet Package Authorize endpoint' do
          detail 'This feature was introduced in GitLab 14.1'
          success code: 200
          failure [
            { code: 401, message: 'Unauthorized' },
            { code: 403, message: 'Forbidden' },
            { code: 404, message: 'Not Found' }
          ]
          tags %w[nuget_packages]
        end
        put 'authorize', urgency: :low do
          authorize_nuget_upload
        end

        # https://docs.microsoft.com/en-us/nuget/api/symbol-package-publish-resource
        desc 'The NuGet Symbol Package Publish endpoint' do
          detail 'This feature was introduced in GitLab 14.1'
          success code: 201
          failure [
            { code: 400, message: 'Bad Request' },
            { code: 401, message: 'Unauthorized' },
            { code: 403, message: 'Forbidden' },
            { code: 404, message: 'Not Found' }
          ]
          tags %w[nuget_packages]
        end
        params do
          use :file_params
        end
        put 'symbolpackage', urgency: :low do
          upload_nuget_package_file(symbol_package: true) do |package|
            track_package_event(
              'push_symbol_package',
              :nuget,
              category: 'API::NugetPackages',
              project: package.project,
              namespace: package.project.namespace
            )
          end
        rescue ObjectStorage::RemoteStoreError => e
          Gitlab::ErrorTracking.track_exception(e, extra: { file_name: params[:file_name], project_id: project_or_group.id })

          forbidden!
        end

        desc 'The NuGet Symbol Package Authorize endpoint' do
          detail 'This feature was introduced in GitLab 14.1'
          success code: 200
          failure [
            { code: 401, message: 'Unauthorized' },
            { code: 403, message: 'Forbidden' },
            { code: 404, message: 'Not Found' }
          ]
          tags %w[nuget_packages]
        end
        put 'symbolpackage/authorize', urgency: :low do
          authorize_nuget_upload
        end

        # https://docs.microsoft.com/en-us/nuget/api/package-base-address-resource
        params do
          requires :package_name, type: String, desc: 'The NuGet package name', regexp: API::NO_SLASH_URL_PART_REGEX, documentation: { example: 'mynugetpkg.1.3.0.17.nupkg' }
        end
        namespace '/download/*package_name' do
          after_validation do
            authorize_read_package!(project_or_group)
          end

          desc 'The NuGet Content Service - index request' do
            detail 'This feature was introduced in GitLab 12.8'
            success code: 200, model: ::API::Entities::Nuget::PackagesVersions
            failure [
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: 'Not Found' }
            ]
            tags %w[nuget_packages]
          end
          get 'index', format: :json, urgency: :low do
            present ::Packages::Nuget::PackagesVersionsPresenter.new(find_packages(params[:package_name])),
                    with: ::API::Entities::Nuget::PackagesVersions
          end

          desc 'The NuGet Content Service - content request' do
            detail 'This feature was introduced in GitLab 12.8'
            success code: 200
            failure [
              { code: 401, message: 'Unauthorized' },
              { code: 403, message: 'Forbidden' },
              { code: 404, message: 'Not Found' }
            ]
            tags %w[nuget_packages]
          end
          params do
            requires :package_version, type: String, desc: 'The NuGet package version', regexp: API::NO_SLASH_URL_PART_REGEX, documentation: { example: '1.3.0.17' }
            requires :package_filename, type: String, desc: 'The NuGet package filename', regexp: API::NO_SLASH_URL_PART_REGEX, documentation: { example: 'mynugetpkg.1.3.0.17.nupkg' }
          end
          get '*package_version/*package_filename', format: [:nupkg, :snupkg], urgency: :low do
            filename = "#{params[:package_filename]}.#{params[:format]}"
            package_file = ::Packages::PackageFileFinder.new(find_package(params[:package_name], params[:package_version]), filename, with_file_name_like: true)
                                                        .execute

            not_found!('Package') unless package_file

            track_package_event(
              params[:format] == 'snupkg' ? 'pull_symbol_package' : 'pull_package',
              :nuget,
              category: 'API::NugetPackages',
              project: package_file.project,
              namespace: package_file.project.namespace
            )

            # nuget and dotnet don't support 302 Moved status codes, supports_direct_download has to be set to false
            present_package_file!(package_file, supports_direct_download: false)
          end
        end
      end
    end
  end
end
