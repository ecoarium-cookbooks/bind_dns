#
# Cookbook Name:: bind_dns
# Recipe:: default
#

include_recipe 'chef_commons'

ecosystem_info = data_bag_item("ecosystem", "instance_info")
master_zone = ecosystem_info[:domain_name]

master_address = data_bag_item('servers', 'dns_master')[:ip]

node[:bind][:packages].each{|pkg|
  package pkg
}

directory node[:bind][:sysconfdir] do
  owner "named"
  group "named"
  mode 0750
end

%w{ data master slaves }.each{|dir_name|
  
  directory "#{node[:bind][:vardir]}/#{dir_name}" do
    owner "named"
    group "named"
    mode "0770"
    recursive true
  end

}

node[:bind][:etc_cookbook_files].each{|file_name|

  cookbook_file "#{node[:bind][:sysconfdir]}/#{file_name}" do
    owner "named"
    group "named"
    mode "0644"
  end

}

node[:bind][:var_cookbook_files].each{|file_name|
  
  cookbook_file "#{node[:bind][:vardir]}/#{file_name}" do
    owner "named"
    group "named"
    mode "0644"
  end

}

execute "rndc-key" do
  command node[:bind][:rndc_keygen]
  not_if { File.exists?("/etc/rndc.key") }
end

file "/etc/rndc.key" do
  owner "named"
  group "named"
  mode "0600"
  action :touch
end

service "named" do
  supports :reload => true, :status => true
  action [ :enable, :start ]
end

template "#{node[:bind][:sysconfdir]}/named.options" do
  owner "named"
  group "named"
  mode  "0644"
  variables(
    :bind_acls => node[:bind][:acls]
  )
  notifies :reload, "service[named]"
end

subzones = data_bag_item(:dns, :subzones)[:subzones]

template "/etc/named.conf" do
  owner "named"
  group "named"
  mode 0644
  variables(
    :master_zone => master_zone,
    :subzones => subzones,
    :master_address => master_address
  )
  notifies :reload, "service[named]"
end

zonedirname = 'master'

unless node[:bind][:zonetype] == 'master'
  zonedirname = 'slaves'
end

servers = data_bag_items('servers')
server = servers["dns_#{node[:bind][:zonetype]}"]

template "/var/named/#{zonedirname}/#{master_zone}" do
  source 'zone.erb'
  owner "named"
  group "named"
  mode 0644

  variables(
    :master_zone => master_zone,
    :subzones => subzones,
    :name_servers => node[:bind][:name_servers],
    :servers => servers,
    :master_address => master_address
  )

  notifies :reload, "service[named]"
end

