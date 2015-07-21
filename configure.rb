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

