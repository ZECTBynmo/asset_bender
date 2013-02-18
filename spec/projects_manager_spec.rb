require "asset_bender_test"

ProjectsManager = AssetBender::ProjectsManager

describe ProjectsManager do
  before(:each) do
    fixture_projects = [
      fixture_path('project1'),
      fixture_path('project2')
    ]

    local_archive = nil

    ProjectsManager.setup fixture_projects, local_archive
  end

  context 'when extracting project from paths' do
    it do
      ProjectsManager.get_project_from_path("bla/foo/whatever/project1/some/file/thing.css").should eq(ProjectsManager.get_project "project1")
    end

    it do
      ProjectsManager.get_project_from_path("file:///bla.lala/crazy/project2/best/code/award.js").should eq(ProjectsManager.get_project "project2")
    end
  end
end
