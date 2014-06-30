require 'spec_helper'

describe Gitlab::ReferenceExtractor do
  it 'extracts username references' do
    subject.analyze "this contains a @user reference"
    expect(subject.users).to eq(["user"])
  end

  it 'extracts issue references' do
    subject.analyze "this one talks about issue #1234"
    expect(subject.issues).to eq(["1234"])
  end

  it 'extracts JIRA issue references' do
    allow(Gitlab.config.gitlab).to receive(:issues_tracker).and_return("jira")
    subject.analyze "this one talks about issue JIRA-1234"
    expect(subject.issues).to eq(["JIRA-1234"])
  end

  it 'extracts merge request references' do
    subject.analyze "and here's !43, a merge request"
    expect(subject.merge_requests).to eq(["43"])
  end

  it 'extracts snippet ids' do
    subject.analyze "snippets like $12 get extracted as well"
    expect(subject.snippets).to eq(["12"])
  end

  it 'extracts commit shas' do
    subject.analyze "commit shas 98cf0ae3 are pulled out as Strings"
    expect(subject.commits).to eq(["98cf0ae3"])
  end

  it 'extracts multiple references and preserves their order' do
    subject.analyze "@me and @you both care about this"
    expect(subject.users).to eq(["me", "you"])
  end

  it 'leaves the original note unmodified' do
    text = "issue #123 is just the worst, @user"
    subject.analyze text
    expect(text).to eq("issue #123 is just the worst, @user")
  end

  it 'handles all possible kinds of references' do
    accessors = Gitlab::Markdown::TYPES.map { |t| "#{t}s".to_sym }
    expect(subject).to respond_to(*accessors)
  end

  context 'with a project' do
    let(:project) { create(:project) }

    it 'accesses valid user objects on the project team' do
      @u_foo = create(:user, username: 'foo')
      @u_bar = create(:user, username: 'bar')
      create(:user, username: 'offteam')

      project.team << [@u_foo, :reporter]
      project.team << [@u_bar, :guest]

      subject.analyze "@foo, @baduser, @bar, and @offteam"
      expect(subject.users_for(project)).to eq([@u_foo, @u_bar])
    end

    it 'accesses valid issue objects' do
      @i0 = create(:issue, project: project)
      @i1 = create(:issue, project: project)

      subject.analyze "##{@i0.iid}, ##{@i1.iid}, and #999."
      expect(subject.issues_for(project)).to eq([@i0, @i1])
    end

    it 'accesses valid merge requests' do
      @m0 = create(:merge_request, source_project: project, target_project: project, source_branch: 'aaa')
      @m1 = create(:merge_request, source_project: project, target_project: project, source_branch: 'bbb')

      subject.analyze "!999, !#{@m1.iid}, and !#{@m0.iid}."
      expect(subject.merge_requests_for(project)).to eq([@m1, @m0])
    end

    it 'accesses valid snippets' do
      @s0 = create(:project_snippet, project: project)
      @s1 = create(:project_snippet, project: project)
      @s2 = create(:project_snippet)

      subject.analyze "$#{@s0.id}, $999, $#{@s2.id}, $#{@s1.id}"
      expect(subject.snippets_for(project)).to eq([@s0, @s1])
    end

    it 'accesses valid commits' do
      commit = project.repository.commit("master")

      subject.analyze "this references commits #{commit.sha[0..6]} and 012345"
      extracted = subject.commits_for(project)
      expect(extracted.size).to eq(1)
      expect(extracted[0].sha).to eq(commit.sha)
      expect(extracted[0].message).to eq(commit.message)
    end
  end
end
