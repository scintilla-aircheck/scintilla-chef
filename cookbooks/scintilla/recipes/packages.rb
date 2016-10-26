include_recipe 'apt'
include_recipe 'build-essential'

# PACKAGES

# packages for python
%w{python3-pip}.each do |pkg|
    package pkg do
        action :install
    end
end

# packages for postgres
%w{libpq-dev}.each do |pkg|
    package pkg do
        action :install
    end
end

# packages for PIL
#%w{libjpeg-dev libjpeg8 libjpeg8-dev libjpeg62 libjpeg62-dev zlib1g-dev libfreetype6 libfreetype6-dev mime-support }.each do |pkg|
#  package pkg do
#    action :install
#  end
#end

# packages for pydub
#%w{ffmpeg }.each do |pkg|
#  package pkg do
#    action :install
#  end
#end

# DIRECTORIES

## django code directory
#directory "/var/django" do
#    owner "www-data"
#    group "www-data"
#    mode "0775"
#end

## virtualevns
#directory "/var/virtualenvs" do
#    owner "www-data"
#    group "opsworks"
#    mode "0775"
#end

## Make virtual env for the app
#python_virtualenv "/var/virtualenvs/#{node.default['app_name']}" do
#    action :create
#    owner "www-data"
#    group "opsworks"
#    options "--distribute"
#end

## Environment directory
#directory "/home/ubuntu/environments/" do
#    mode 0775
#    owner 'ubuntu'
#    group 'admin'
#    action :create
#end
