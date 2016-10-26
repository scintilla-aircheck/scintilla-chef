default['app_name'] = 'scintilla'
default['cloud_user'] = 'scintilla'
default['cloud_group'] = 'scintilla'
default['app_user_and_group'] = 'app'
default['app_folder'] = 'scintilla_api'
default['app_repo'] = 'git://github.com/scintilla-aircheck/scintilla-api.git'
default['app_branch'] = 'master'
default['gunicorn']['maxrequests'] = 5000
default['gunicorn']['workers'] = 9
default['gunicorn']['timeout'] = 180
default['migrate'] = true
default['poise-python']['install_python2'] = false
default['poise-python']['install_python3'] = true

default['nginx']['certs'] = "/etc/nginx/certs"
default['domains'] = [{ 'domain' => 'scintilla-dev.centralus.cloudapp.azure.com', 'key' => 'airqualityhq.key', 'cert' => 'airqualityhq.crt', 'ssl' => false }]
default['django_port'] = 8000