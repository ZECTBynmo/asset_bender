require "asset_bender_test"

State = AssetBender::State

describe State do
  before(:each) do
    fixture_projects = [
      fixture_path('project1'),
      fixture_path('project2')
    ]

    local_archive = nil

    State.setup fixture_projects, local_archive
  end

  context 'when extracting project from paths' do
    it do
      State.get_project_from_path("bla/foo/whatever/project1/some/file/thing.css").should eq(State.get_project "project1")
    end

    it do
      State.get_project_from_path("file:///bla.lala/crazy/project2/best/code/award.js").should eq(State.get_project "project2")
    end
  end
end
