require "spec_helper"

describe API::API, api: true  do
  include ApiHelpers
  let(:user) { create(:user) }
  let(:project) {create(:project, creator_id: user.id, namespace: user.namespace) }

  describe "POST /projects/:id/services/gitlab-ci" do
    it "should update gitlab-ci settings" do
      put api("/projects/#{project.id}/services/gitlab-ci", user), token: 'secret-token', project_url: "http://ci.example.com/projects/1"

      expect(response.status).to eq(200)
    end

    it "should return if required fields missing" do
      put api("/projects/#{project.id}/services/gitlab-ci", user), project_url: "http://ci.example.com/projects/1", active: true

      expect(response.status).to eq(400)
    end
  end

  describe "DELETE /projects/:id/services/gitlab-ci" do
    it "should update gitlab-ci settings" do
      delete api("/projects/#{project.id}/services/gitlab-ci", user)

      expect(response.status).to eq(200)
      expect(project.gitlab_ci_service).to be_nil
    end
  end
end
