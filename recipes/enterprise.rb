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

unless FileTest.exists?("#{node['neo4j']['server_bin']}/neo4j")
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
      mv -f neo4j-enterprise-#{node['neo4j']['server_version']} #{node['neo4j']['server_path']}
    EOF
    action :run
  end
end

link "/etc/init.d/neo4j-service" do
  to "#{node['neo4j']['server_path']}/bin/neo4j"
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