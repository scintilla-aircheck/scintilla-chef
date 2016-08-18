include_recipe "scintilla::packages"

def deploy(appname, settings)
  instance = search("aws_opsworks_instance").first

  hostname = instance['hostname']
  environment = settings[:environment].to_hash
  supervisor_environment = environment.map{|k,v| "#{k}=\"#{v}\""}.join(',')

  # Make environment settings for ubuntu
  name = 'ubuntu'

  # make environments directory
  directory "/home/#{name}/environments" do
    owner name
    group "admin"
    mode "0775"
  end

  template "/home/#{name}/environments/#{appname}-environment.conf" do
    source "environment.settings.conf.erb"
    owner name
    group "admin"
    variables(:environment => settings[:environment], :appname => appname)
  end

  # checkout the branch from repo
  git "/var/django/#{settings[:folder]}" do
    repository settings[:repo]
    reference settings[:branch]
    user "www-data"
    group "www-data"
    action :sync
  end

  # install/update the requirements for virtualenv
  bash "installing/updating requirements for #{appname}" do
    code <<-EOH
      source /var/virtualenvs/#{appname}/bin/activate
      cd /var/django/#{settings[:folder]}
      pip install -r requirements.txt
    EOH
  end

  # web - supervisor conf file
  template "/etc/supervisor.d/#{appname}.conf" do
    source "web.conf.erb"
    owner "root"
    group "opsworks"
    mode "0775"
    variables(:appname => appname, :settings => settings, :supervisor_environment => supervisor_environment, :private_ip => instance['private_ip'])
    notifies :reload, "service[supervisor]", :delayed
  end

  # if main server - setup celerybeat and sync any static content
  if [settings[:main_server]].include? hostname then
    if settings[:celerybeat] then
      # create the supervisord program entry for celerybeat
      template "/etc/supervisor.d/#{appname}.celerybeat.conf" do
        source "celerybeat.conf.erb"
        variables(:appname => appname, :settings => settings, :supervisor_environment => supervisor_environment)
        notifies :reload, "service[supervisor]", :delayed
        owner "root"
        group "opsworks"
        mode "0775"
      end
    end

    if settings[:environment][:APP_ENV].upcase == "STAGING" || settings[:environment][:APP_ENV].upcase == "PRODUCTION" then
      bash "syncing static files" do
        code <<-EOH
          source /home/ubuntu/environments/#{appname}-environment.conf
          cd /var/django/#{settings[:folder]}
          python ./manage.py collectstatic --noinput
          python ./manage.py sync_s3 --static-only
        EOH
      end
    else
      bash "syncing static files" do
        code <<-EOH
          source /home/ubuntu/environments/#{appname}-environment.conf
          cd /var/django/#{settings[:folder]}
          python ./manage.py collectstatic --noinput
        EOH
      end
    end
  end

  # celery - supervisor conf file
  template "/etc/supervisor.d/#{appname}.celery.conf" do
    source "celery.conf.erb"
    owner "root"
    group "opsworks"
    mode "0775"
    variables(:appname => appname, :settings => settings, :supervisor_environment => supervisor_environment)
    notifies :reload, "service[supervisor]", :delayed
  end

  bash "supervisor-update" do
    code <<-EOH
      supervisorctl update
    EOH
  end

  bash "supervisor-reload-server" do
    code <<-EOH
      supervisorctl restart #{appname}
    EOH
  end

  # restart webs
  bash "restarting gunicorn workers" do
    code <<-EOH
      if [[ -e /var/django/#{appname}.pid ]]; then
        sudo kill -HUP `cat /var/django/#{appname}.pid`
      fi
    EOH
  end

  # restart celery workers
  if settings[:celerybeat] then
    bash "restarting celery" do
      code <<-EOH
        supervisorctl restart #{appname}-worker
      EOH
    end
  end

  # migration
  if settings[:migrate] then
    code <<-EOH
      cd /var/django/#{settings[:folder]}
      source /home/#{name}/environments/#{appname}-environment.conf
      python #{settings[:app_folder]}/manage.py migrate
    EOH
  end

end


node[:apps].each do | appname, settings|
  deploy(appname, settings)
end
