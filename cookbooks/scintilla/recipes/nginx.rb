include_recipe "nginx"

# Make nginx dir
directory node[:nginx][:certs] do
  owner "root"
  group "root"
  mode "0775"
end

template "nginx/proxy.conf" do
  path "#{node[:nginx][:dir]}/proxy.conf"
  source "proxy.conf.erb"
  owner "root"
  group "root"
  mode "0644"
end

def nginx(appname, settings)

  layer = search("aws_opsworks_layer", "shortname:app-servers").first
  instances = search("aws_opsworks_instance", "layer_ids:#{layer['layer_id']}")

  template "nginx/upstreams.conf" do
    path "#{node[:nginx][:dir]}/conf.d/#{appname}.conf"
    source "upstreams.conf.erb"
    owner "root"
    group "root"
    mode "0644"
    variables(:appname => appname, :settings => settings, :instances => instances)
    notifies :reload, "service[nginx]", :immediately
  end

  settings[:domains].each do |domain|

    # Copy certs for each domain in to nginx certs folder
    if domain[:ssl]
      [domain[:cert], domain[:key]].each do |cert_name|
        cookbook_file "#{node['nginx']['certs']}/#{cert_name}" do
          source "#{cert_name}"
          owner "root"
          group "root"
          mode 00644
        end
      end
    end

    template "nginx/sites.conf" do
      path "#{node[:nginx][:dir]}/sites-available/#{domain[:domain]}.conf"
      source "sites.conf.erb"
      owner "root"
      group "root"
      mode "0644"
      variables(:appname => appname, :domain => domain[:domain], :push_server => settings[:push_server], :settings => domain)
      notifies :reload, "service[nginx]", :immediately
    end
  end

  # sym link from sites-available to sites-enabled
  settings[:domains].each do |domain|
    config = "#{domain[:domain]}.conf"
    link config do
      target_file "#{node[:nginx][:dir]}/sites-enabled/#{config}"
      to "#{node[:nginx][:dir]}/sites-available/#{config}"
      notifies :reload, "service[nginx]", :immediately
    end
  end

  # This is to fix an issue with nginx where it bootups but does not set the PID files, which causes it to not be allowed to be restarted / reloaded etc
  #execute "manually set nginx pids" do
  #  command "ps -ef | grep nginx | grep master | gawk '{print $2}' > /run/nginx.pid"
  #  command "ps -ef | grep nginx | grep master | gawk '{print $2}' > /var/run/nginx.pid"
  #end

  service "nginx" do
    action :start
    supports :status => true, :restart => true, :reload => true
  end
end

node[:apps].each do | appname, settings|
  nginx(appname, settings)
end
