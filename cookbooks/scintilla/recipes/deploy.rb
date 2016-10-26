include_recipe "scintilla::packages"
include_recipe "git::default"
include_recipe "supervisor"
include_recipe "nginx"

environment = data_bag_item('scintilla', 'environment')
supervisor_environment = environment.map{|k,v| "#{k}=\"#{v}\""}.join(',')

user node['app_user_and_group'] do
    action :create
    shell '/bin/bash'
end

group node['app_user_and_group'] do
    action :create
    members [node['app_user_and_group']]
end

# django code directory
directory "/var/django" do
    owner node['app_user_and_group']
    group node['app_user_and_group']
    mode "0775"
end

# virtualevns
directory "/var/virtualenvs" do
    owner node['app_user_and_group']
    group node['app_user_and_group']
    mode "0775"
end

## Make virtual env for the app
python_virtualenv "/var/virtualenvs/#{node['app_name']}" do
    action :create
    user node['app_user_and_group']
    group node['app_user_and_group']
end

# make environments directory
directory "/home/#{node['cloud_user']}/environments" do
    owner node['cloud_user']
    group node['cloud_group']
    mode "0775"
end

template "/home/#{node['cloud_user']}/environments/#{node['app_name']}-environment.conf" do
    source "environment.settings.conf.erb"
    owner node['cloud_user']
    group node['cloud_group']
    variables(:environment => environment, :app_name => node['app_name'])
end

# checkout the branch from repo
git "/var/django/#{node['app_folder']}" do
    repository node['app_repo']
    reference node['app_branch']
    user node['app_user_and_group']
    group node['app_user_and_group']
    action :sync
end

bash "checking out all submodules" do
    code <<-EOH
        cd /var/django/#{node['app_folder']}
        git submodule init
        git submodule update
        EOH
end

# install/update the requirements for virtualenv
bash "installing/updating requirements for #{node['app_name']}" do
    code <<-EOH
        cd /var/django/#{node['app_folder']}
        pip3 install -r requirements.txt
        EOH
end

# # gunicorn - supervisor conf file
# @template "/etc/supervisor.d/gunicorn.conf" do
#    source "gunicorn.conf.erb"
#    owner node['cloud_user']
#    group node['cloud_group']
#    mode "0775"
#    variables(:app_name => node['app_name'], :app_folder => node['app_folder'], :app_user => node['app_user_and_group'], :gunicorn => node['gunicorn'], :supervisor_environment => supervisor_environment)
#    notifies :reload, "service[supervisor]", :delayed
# end

# worker - supervisor conf file
template "/etc/supervisor.d/worker.conf" do
    source "worker.conf.erb"
    owner node['cloud_user']
    group node['cloud_group']
    mode "0775"
    variables(:app_name => node['app_name'], :app_folder => node['app_folder'], :user => node['cloud_user'], :supervisor_environment => supervisor_environment)
    notifies :reload, "service[supervisor]", :delayed
end

# celery - supervisor conf file
template "/etc/supervisor.d/celery.conf" do
    source "celery.conf.erb"
    owner node['cloud_user']
    group node['cloud_group']
    mode "0775"
    variables(:app_name => node['app_name'], :app_folder => node['app_folder'], :user => node['cloud_user'], :supervisor_environment => supervisor_environment)
    notifies :reload, "service[supervisor]", :delayed
end

# daphne - supervisor conf file
template "/etc/supervisor.d/daphne.conf" do
    source "daphne.conf.erb"
    owner node['cloud_user']
    group node['cloud_group']
    mode "0775"
    variables(:app_name => node['app_name'], :app_folder => node['app_folder'], :user => node['cloud_user'], :port => node['django_port'], :supervisor_environment => supervisor_environment)
    notifies :reload, "service[supervisor]", :delayed
end

bash "supervisor-update" do
    code <<-EOH
        supervisorctl update
        EOH
end

bash "supervisor-reload-server" do
    code <<-EOH
        supervisorctl restart worker
        supervisorctl restart daphne
        EOH
end

# # restart gunicorn workers
# bash "restarting gunicorn workers" do
#    code <<-EOH
#        if [[ -e /var/django/#{node['app_name']}.pid ]]; then
#            sudo kill -HUP `cat /var/django/#{node['app_name']}.pid`
#        fi
#        EOH
# end

# migration
if node['migrate'] then
    bash "migrating" do
        code <<-EOH
            cd /var/django/#{node['app_folder']}
            source /home/#{node['cloud_user']}/environments/#{node['app_name']}-environment.conf
            python3 manage.py migrate
            EOH
    end
end

# make sure that db.sqlite3 is owned by app
file "/var/django/#{node['app_folder']}/db.sqlite3" do
    owner node['app_user_and_group']
    group node['app_user_and_group']
    mode "0644"
end

# collect static
bash "collecting static" do
    code <<-EOH
        cd /var/django/#{node['app_folder']}
        source /home/#{node['cloud_user']}/environments/#{node['app_name']}-environment.conf
        python3 manage.py collectstatic --noinput
        EOH
end

### NGINX

# Make nginx dir
directory node['nginx']['certs'] do
  owner node['cloud_user']
  group node['cloud_user']
  mode "0775"
end

template "nginx/proxy.conf" do
  path "#{node[:nginx][:dir]}/proxy.conf"
  source "proxy.conf.erb"
  owner node['cloud_user']
  group node['cloud_user']
  mode "0644"
end

template "nginx/upstreams.conf" do
    path "#{node[:nginx][:dir]}/conf.d/#{node['app_name']}.conf"
    source "upstreams.conf.erb"
    owner node['cloud_user']
    group node['cloud_user']
    mode "0644"
    variables(:app_name => node['app_name'], :port => node['django_port'])
    notifies :reload, "service[nginx]", :immediately
end

node['domains'].each do |domain|

    # Copy certs for each domain in to nginx certs folder
    if domain[:ssl]
        [domain[:cert], domain[:key]].each do |cert_name|
            cookbook_file "#{node['nginx']['certs']}/#{cert_name}" do
                source "#{cert_name}"
                owner node['cloud_user']
                group node['cloud_user']
                mode 00644
            end
        end
    end

    template "nginx/sites.conf" do
        path "#{node[:nginx][:dir]}/sites-available/#{domain['domain']}.conf"
        source "sites.conf.erb"
        owner node['cloud_user']
        group node['cloud_user']
        mode "0644"
        variables(:app_name => node['app_name'], :domain => domain)
        notifies :reload, "service[nginx]", :immediately
    end

    # sym link from sites-available to sites-enabled
    config = "#{domain['domain']}.conf"
    link config do
        target_file "#{node[:nginx][:dir]}/sites-enabled/#{config}"
          to "#{node[:nginx][:dir]}/sites-available/#{config}"
      notifies :reload, "service[nginx]", :immediately
    end
end

# This is to fix an issue with nginx where it bootups but does not set the PID files, which causes it to not be allowed to be restarted / reloaded etc
# execute "manually set nginx pids" do
#  command "ps -ef | grep nginx | grep master | gawk '{print $2}' > /run/nginx.pid"
#  command "ps -ef | grep nginx | grep master | gawk '{print $2}' > /var/run/nginx.pid"
# end

service "nginx" do
    action :start
    supports :status => true, :restart => true, :reload => true
end
