#
# Cookbook Name:: neo4j
# Recipe:: default
#
# Copyright 2012, SourceIndex IT-Serives
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

case node['platform']
when "debian", "ubuntu"
  include_recipe 'apt'
when "centos","redhat"
  include_recipe 'yum'
  package "lsof"
end

include_recipe "java"

#stop our service
service "neo4j-service" do
  action :stop
end

remote_file "#{Chef::Config[:file_cache_path]}/#{node['neo4j']['server_file']['enterprise']}" do
  source node['neo4j']['server_download']['enterprise']
end

execute "install neo4j sources #{node['neo4j']['server_file']['enterprise']}" do
  user "root"
  group "root"
  cwd Chef::Config[:file_cache_path]
  command <<-EOF
    tar -zxf #{node['neo4j']['server_file']['enterprise']}
    chown -R root:root neo4j-enterprise-#{node['neo4j']['server_version']}
    if [ -d "#{node['neo4j']['server_path']}/data" ]; then cp -r "#{node['neo4j']['server_path']}/data" /tmp/; fi
    if [ -d "#{node['neo4j']['server_path']}" ]; then rm -rf "#{node['neo4j']['server_path']}"; fi
    mkdir -p #{node['neo4j']['server_path']}
    cp -rp neo4j-enterprise-#{node['neo4j']['server_version']}/* #{node['neo4j']['server_path']}/
    if [ -d "/tmp/data" ]; then cp -r /tmp/data "#{node['neo4j']['server_path']}/"; rm -r /tmp/data fi
    rm -rf neo4j-enterprise-#{node['neo4j']['server_version']}
  EOF
  action :run
end

#fix our directory structure
execute "Set permissions on #{node['neo4j']['server_path']}" do
  user "root"
  group "root"
  command <<-EOF
    chown -R #{node['neo4j']['server_user']}.#{node['neo4j']['server_group']} #{node['neo4j']['server_path']}
    chmod -R 744 #{node['neo4j']['server_path']}
  EOF
  action :run
end
    
link "/etc/init.d/neo4j-service" do
  to "#{node['neo4j']['server_path']}/bin/neo4j"
end

#allow us to upgrade from an older database
file_replace_line "neo4j.properties" do
  replace "#allow_store_upgrade=true"
  with    "allow_store_upgrade=true"
  path "#{node['neo4j']['server_path']}/conf/neo4j.properties"
end

#run services as dmps
file_replace_line "neo4j" do
  replace "DEFAULT_USER='neo4j'"
  with    "DEFAULT_USER='#{node['neo4j']['server_user']}'"
  path "#{node['neo4j']['server_path']}/bin/neo4j"
end

execute "setting the systems ulimits" do 
  # http://wiki.basho.com/Open-Files-Limit.html
  user "root"
  group "root"
  command <<-EOF
    echo "ulimit -n #{node['neo4j']['server_ulimit']}" > /etc/default/neo4j
  EOF
  action :run
end

service "neo4j-service" do
  supports :start => true, :stop => true, :status => true, :restart => true
  action [:enable, :start]
end