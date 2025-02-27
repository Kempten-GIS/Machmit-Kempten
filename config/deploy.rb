# config valid only for current version of Capistrano
lock "~> 3.17.3"

def deploysecret(key)
  @deploy_secrets_yml ||= YAML.load_file("config/deploy-secrets/deploy-secrets-cli_kemp.yml")[fetch(:stage).to_s]
  @deploy_secrets_yml.fetch(key.to_s, "undefined")
end

set :rails_env, fetch(:stage)
set :rvm1_map_bins, -> { fetch(:rvm_map_bins).to_a.concat(%w[rake gem bundle ruby]).uniq }

set :application, "consul"
set :deploy_to, deploysecret(:deploy_to)
set :ssh_options, port: deploysecret(:ssh_port)

set :repo_url, "https://github.com/hanuschka/consul.git"

set :revision, `git rev-parse --short #{fetch(:branch)}`.strip

set :log_level, :info
set :pty, true
set :use_sudo, false

set :linked_files, %w[config/database.yml config/secrets.yml config/secret_emails.yml]
set :linked_dirs, %w[.bundle log tmp public/system public/assets public/ckeditor_assets public/machine_learning/data storage]

set :keep_releases, 5

set :local_user, ENV["USER"]

set :fnm_path, "$HOME/.fnm"
set :fnm_install_command, "curl -fsSL https://fnm.vercel.app/install | " \
                          "bash -s -- --install-dir \"#{fetch(:fnm_path)}\""
set :fnm_update_command, "#{fetch(:fnm_install_command)} --skip-shell"
set :fnm_setup_command, -> do
                          "export PATH=\"#{fetch(:fnm_path)}:$PATH\" && " \
                            "cd #{release_path} && fnm env > /dev/null && eval \"$(fnm env)\""
                        end
set :fnm_install_node_command, -> { "#{fetch(:fnm_setup_command)} && fnm use --install-if-missing" }
set :fnm_map_bins, %w[bundle node npm puma pumactl rake yarn]

set :puma_conf, "#{release_path}/config/puma/#{fetch(:rails_env)}.rb"
set :puma_systemctl_user, :user

set :delayed_job_workers, 2
set :delayed_job_roles, :background

set :whenever_roles, -> { :app }

namespace :deploy do
  after "rvm1:hook", "map_node_bins"

  after :updating, "install_node"
  after :updating, "install_ruby"

  after "deploy:migrate", "add_new_settings"

  after :publishing, "setup_puma"
  before "puma:smart_restart", "stop_puma_daemon"
  after :finished, "restart_delayed_jobs"
  after :finished, "refresh_sitemap"

  desc "Deploys and runs the tasks needed to upgrade to a new release"
  task :upgrade do
    after "add_new_settings", "execute_release_tasks"
    invoke "deploy"
  end

  before "deploy:restart", "puma:smart_restart"
end

task :install_ruby do
  on roles(:app) do
    within release_path do
      begin
        current_ruby = capture(:rvm, "current")
      rescue SSHKit::Command::Failed
        after "install_ruby", "rvm1:install:rvm"
        after "install_ruby", "rvm1:install:ruby"
      else
        if current_ruby.include?("not installed")
          after "install_ruby", "rvm1:install:rvm"
          after "install_ruby", "rvm1:install:ruby"
        else
          info "Ruby: Using #{current_ruby}"
        end
      end
    end
  end
end

task :install_node do
  on roles(:app) do
    with rails_env: fetch(:rails_env) do
      begin
        execute fetch(:fnm_install_node_command)
      rescue SSHKit::Command::Failed
        begin
          execute fetch(:fnm_setup_command)
        rescue SSHKit::Command::Failed
          execute fetch(:fnm_install_command)
        else
          execute fetch(:fnm_update_command)
        end

        execute fetch(:fnm_install_node_command)
      end
    end
  end
end

task :map_node_bins do
  on roles(:app) do
    within release_path do
      with rails_env: fetch(:rails_env) do
        prefix = -> { "#{fetch(:fnm_path)}/fnm exec" }

        fetch(:fnm_map_bins).each do |command|
          SSHKit.config.command_map.prefix[command.to_sym].unshift(prefix)
        end
      end
    end
  end
end

task :refresh_sitemap do
  on roles(:app) do
    within release_path do
      with rails_env: fetch(:rails_env) do
        execute :rake, "sitemap:refresh:no_ping"
      end
    end
  end
end

task :add_new_settings do
  on roles(:db) do
    within release_path do
      with rails_env: fetch(:rails_env) do
        execute :rake, "settings:add_new_settings"
        execute :rake, "settings:destroy_obsolete"
        execute :rake, "projekt_settings:ensure_existence"
        execute :rake, "projekt_settings:destroy_obsolete"
        execute :rake, "projekt_phase_settings:add_new_settings"
        execute :rake, "projekt_phase_settings:destroy_obsolete"
        execute :rake, "deficiency_report_statuses:add_default_statuses"
      end
    end
  end
end

task :execute_release_tasks do
  on roles(:app) do
    within release_path do
      with rails_env: fetch(:rails_env) do
        execute :rake, "consul:execute_release_tasks"
      end
    end
  end
end

task :restart_delayed_jobs do
  on roles(:app) do
    within release_path do
      with rails_env: fetch(:rails_env) do
        execute "sudo systemctl restart delayed_job2"
      end
    end
  end
end

desc "Create pid and socket folders needed by puma"
task :setup_puma do
  on roles(fetch(:puma_role)) do
    with rails_env: fetch(:rails_env) do
      execute "mkdir -p #{shared_path}/tmp/sockets; true"
      execute "mkdir -p #{shared_path}/tmp/pids; true"
    end
  end

  after "setup_puma", "puma:systemd:config"
  after "setup_puma", "puma:systemd:enable"
end

# Code adapted from the task to stop the daemon in capistrano3-puma
desc "Stops the Puma daemon so systemd can start the Puma process"
task :stop_puma_daemon do
  on roles(fetch(:puma_role)) do |role|
    within release_path do
      with rails_env: fetch(:rails_env) do
        if test("[ -f #{fetch(:puma_pid)} ]") &&
           !test("systemctl --user is-active #{fetch(:puma_service_unit_name)}") &&
           test(:kill, "-0 $( cat #{fetch(:puma_pid)} )")
          info "Puma: stopping daemon"
          execute :pumactl, "-S #{fetch(:puma_state)} -F #{fetch(:puma_conf)} stop"
        end
      end
    end
  end
end
