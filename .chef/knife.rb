# See http://docs.chef.io/config_rb_knife.html for more information on knife configuration options

current_dir = File.dirname(__FILE__)
log_level                :info
log_location             STDOUT
node_name                "scintilla"
client_key               "#{current_dir}/scintilla.pem"
chef_server_url          "https://api.chef.io/organizations/scintilla"
cookbook_path            ["#{current_dir}/../cookbooks"]
encrypted_data_bag_secret "#{currrent_dir}/encrypted_data_bag_secret"
