class Spinach::Features::ProjectCommits < Spinach::FeatureSteps
  include SharedAuthentication
  include SharedProject
  include SharedPaths
  include RepoHelpers

  step 'I see project commits' do
    commit = @project.repository.commit
    page.should have_content(@project.name)
    page.should have_content(commit.message[0..20])
    page.should have_content(commit.short_id)
  end

  step 'I click atom feed link' do
    click_link "Commits Feed"
  end

  step 'I see commits atom feed' do
    commit = @project.repository.commit
    response_headers['Content-Type'].should have_content("application/atom+xml")
    body.should have_selector("title", text: "#{@project.name}:master commits")
    body.should have_selector("author email", text: commit.author_email)
    body.should have_selector("entry summary", text: commit.description[0..10])
  end

  step 'I click on commit link' do
    visit namespace_project_commit_path(@project.namespace, @project, sample_commit.id)
  end

  step 'I see commit info' do
    page.should have_content sample_commit.message
    page.should have_content "Showing #{sample_commit.files_changed_count} changed files"
  end

  step 'I fill compare fields with refs' do
    fill_in "from", with: sample_commit.parent_id
    fill_in "to",   with: sample_commit.id
    click_button "Compare"
  end

  step 'I unfold diff' do
    @diff = first('.js-unfold')
    @diff.click
    sleep 2
  end

  step 'I should see additional file lines' do
    page.within @diff.parent do
      first('.new_line').text.should_not have_content "..."
    end
  end

  step 'I see compared refs' do
    page.should have_content "Compare View"
    page.should have_content "Commits (1)"
    page.should have_content "Showing 2 changed files"
  end

  step 'I see breadcrumb links' do
    page.should have_selector('ul.breadcrumb')
    page.should have_selector('ul.breadcrumb a', count: 4)
  end

  step 'I see commits stats' do
    page.should have_content 'Top 50 Committers'
    page.should have_content 'Committers'
    page.should have_content 'Total commits'
    page.should have_content 'Authors'
  end

  step 'I visit big commit page' do
    stub_const('Commit::DIFF_SAFE_FILES', 20)
    visit namespace_project_commit_path(@project.namespace, @project, sample_big_commit.id)
  end

  step 'I see big commit warning' do
    page.should have_content sample_big_commit.message
    page.should have_content "Too many changes"
  end

  step 'I visit a commit with an image that changed' do
    visit namespace_project_commit_path(@project.namespace, @project, sample_image_commit.id)
  end

  step 'The diff links to both the previous and current image' do
    links = page.all('.two-up span div a')
    links[0]['href'].should =~ %r{blob/#{sample_image_commit.old_blob_id}}
    links[1]['href'].should =~ %r{blob/#{sample_image_commit.new_blob_id}}
  end

  step 'I click side-by-side diff button' do
    click_link "Side-by-side"
  end

  step 'I see side-by-side diff button' do
    page.should have_content "Side-by-side"
  end

  step 'I see inline diff button' do
    page.should have_content "Inline"
  end
end
