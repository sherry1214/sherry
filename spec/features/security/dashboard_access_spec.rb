require 'spec_helper'

describe "Dashboard access", feature: true  do
  describe "GET /dashboard" do
    subject { dashboard_path }

    it { should be_allowed_for :admin }
    it { should be_allowed_for :user }
    it { should be_denied_for :visitor }
  end

  describe "GET /dashboard/issues" do
    subject { issues_dashboard_path }

    it { should be_allowed_for :admin }
    it { should be_allowed_for :user }
    it { should be_denied_for :visitor }
  end

  describe "GET /dashboard/merge_requests" do
    subject { merge_requests_dashboard_path }

    it { should be_allowed_for :admin }
    it { should be_allowed_for :user }
    it { should be_denied_for :visitor }
  end

  describe "GET /dashboard/projects" do
    subject { projects_dashboard_path }

    it { should be_allowed_for :admin }
    it { should be_allowed_for :user }
    it { should be_denied_for :visitor }
  end

  describe "GET /help" do
    subject { help_path }

    it { should be_allowed_for :admin }
    it { should be_allowed_for :user }
    it { should be_denied_for :visitor }
  end

  describe "GET /projects/new" do
    it { expect(new_project_path).to be_allowed_for :admin }
    it { expect(new_project_path).to be_allowed_for :user }
    it { expect(new_project_path).to be_denied_for :visitor }
  end

  describe "GET /groups/new" do
    it { expect(new_group_path).to be_allowed_for :admin }
    it { expect(new_group_path).to be_allowed_for :user }
    it { expect(new_group_path).to be_denied_for :visitor }
  end
end
