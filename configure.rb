#!/usr/bin/ruby
#
# This is a sample script that configures some basic Foreman settings
# The script can be extended to configure a fully working Foreman env
#

$debug = true

hammer_user = 'admin'
hammer_pass = 'password'
root_pass = `openssl passwd -1 "password"`.chomp

$hammer = "hammer -u #{hammer_user} -p #{hammer_pass}"


##########################################
### helper functions
##########################################

def debug_out(output)
  if $debug
    puts output
  end
end

def find_id(param, search)
  return `#{$hammer} --csv #{param} list --search \"#{search}\" | grep -v Id | head -1 | awk -F, '{print $1}'`.chomp
end

def hammer_multiarg(cmd, hash)
  args = ""
  hash.each_pair do |key, val|
    args << "--#{key} \"#{val}\" "
  end
  return `#{$hammer} #{cmd} #{args}`
end


##########################################
### general settings
##########################################

# define
settings = Hash.new
settings['require_ssl_smart_proxies'] = 'false'
settings['restrict_registered_smart_proxies'] = 'false'
settings['root_pass'] = root_pass

# set
settings.each_pair do |key, val|
  debug_out `#{$hammer} settings set --name #{key} --value \'#{val}\' 2>&1`
end

##########################################
### global parameters
##########################################

# define
global_param = Hash.new
global_param['enable-puppetlabs-repo'] = 'true'
global_param['force-puppet'] = 'true'

# set
global_param.each_pair do |key, val|
  debug_out `#{$hammer} global-parameter set --name #{key} --value #{val} 2>&1`
end

##########################################
### environments
##########################################

# define
environments = Hash.new
environments['name'] = 'production'

# set
debug_out `#{$hammer} environment create --name #{environments['name']} 2>&1`

##########################################
### proxies
##########################################

# define
proxies = Hash.new{|hash, key| hash[key] = Hash.new}
proxies['infra'][:url] = 'http://172.16.16.101:8000'

# configure
proxies.each_key do |key|
  debug_out `#{$hammer} proxy create --name #{key} --url #{proxies[key][:url]} 2>&1`
  proxies[key][:id] = find_id('proxy', key)
end


##########################################
### os
##########################################

# define
os = Hash.new
os['name'] = 'Ubuntu'
os['major'] = '14.04'
os['family'] = 'Debian'
os['architectures'] = 'x86_64'
os['release-name'] = 'vivid'
os['media'] = 'Ubuntu mirror'
os['partition-tables'] = 'Preseed default'
os_templates = ['Preseed default', 'Preseed default PXELinux', 'Preseed default finish']

# set
hammer_multiarg 'os create', os

# add os to templates
templates = Hash.new
templates['operatingsystem'] = "#{os['name']} #{os['major']}"

os_templates.each do |temp|
  templates['name'] = temp
  hammer_multiarg 'template add-operatingsystem', templates
end

# map templates to os
map_templates = Hash.new
map_templates['id'] = '1'
map_templates['provisioning-templates'] = os_templates.join(',')
hammer_multiarg 'os update', map_templates

# set default templates
default_templates = Hash.new
default_templates['id'] = '1'
`#{$hammer} template list |grep 'Preseed default' |grep -E '(provision|PXELinux|finish)' |awk '{print $1}'`.each do |id|
  default_templates['config-template-id'] = id
  hammer_multiarg 'os set-default-template', default_templates
end

# create chef_integration snippet
snippet = Hash.new
snippet['name'] = 'chef_integration'
snippet['type'] = 'snippet'
snippet['file'] = '/vagrant/snippet/chef_integration.erb'
hammer_multiarg 'template create', snippet

# update finish template
`hammer template dump --name "Preseed default finish" > /tmp/temp.erb`
`echo "<%= snippet 'chef_integration' %>" >> /tmp/temp.erb`

update_temp = Hash.new
update_temp['name'] = 'Preseed default finish'
update_temp['file'] = '/tmp/temp.erb'
hammer_multiarg 'template update', update_temp

##########################################
### domain
##########################################

# define
domain = Hash.new
domain['name'] = 'example.com'
domain['dns-id'] = '1'

# set
hammer_multiarg 'domain create', domain

##########################################
### subnet
##########################################

# define
subnet = Hash.new
subnet['name'] = '172-16-16-0_24'
subnet['network'] = '172.16.16.0'
subnet['mask'] = '255.255.255.0'
subnet['ipam'] = 'DHCP'
subnet['boot-mode'] = 'DHCP'
subnet['domain-ids'] = '1'
subnet['dhcp-id'] = '1'
subnet['dns-id'] = '1'
subnet['tftp-id'] = '1'

# set
hammer_multiarg 'subnet create', subnet

