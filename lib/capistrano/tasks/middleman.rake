require 'tempfile'
require 'rake'

namespace :middleman do
  middleman_options = Array(fetch(:middleman_options, %w(--verbose)))

  archive_name      = fetch :archive_name, Tempfile.new(%w(deploy .tar.gz))
  build_dir         = fetch :build_dir, File.expand_path('build')
  exclude_dir       = Array(fetch(:exclude_dir))

  exclude_args      = exclude_dir.map { |dir| "--exclude '#{dir}'"}
  tar_roles         = fetch(:tar_roles, :all)

  task :build do
    cmd = []
    cmd << 'middleman'
    cmd << 'build'
    cmd.concat middleman_options

    sh cmd.join(' ')
  end

  desc "Archive files to #{archive_name}"
  file archive_name => FileList[build_dir].exclude(archive_name) do |t|
    Rake::Task['middleman:build'].invoke
    cmd = ["tar -cvzf #{t.name}", *exclude_args, *t.prerequisites]
    sh cmd.join(' ')
  end

  desc "Deploy #{archive_name} to release_path"
  task :deploy => archive_name do |t|
    tarball = t.prerequisites.first

    on roles(tar_roles) do
      # Make sure the release directory exists
      puts "==> release_path: #{release_path} is created on #{tar_roles} roles <=="
      execute :mkdir, "-p", release_path

      # Create a temporary file on the server
      tmp_file = capture('mktemp')

      # Upload the archive, extract it and finally remove the tmp_file
      upload!(tarball, tmp_file)
      execute :tar, '-xzf', tmp_file, '-C', release_path
      execute :rm, tmp_file
    end

    Rake::Task['middleman:clean'].invoke
  end

  task :clean do |t|
    # Delete the local archive
    archive_name.unlink
  end

  task :create_release => :deploy
  task :check
  task :set_current_revision
end
