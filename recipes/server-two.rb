#
# Cookbook Name:: mysql-openstack
# Recipe:: server-two
#
# Copyright 2012, Rackspace US, Inc.
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
# replication parts inspired by https://gist.github.com/1105416

include_recipe "osops-utils"
include_recipe "monitoring"
include_recipe "mysql::ruby"
require 'mysql'

# Lookup endpoint info, and properly set mysql attributes
mysql_info = get_bind_endpoint("mysql", "db")
mysql_network = node["mysql"]["services"]["db"]["network"]
bind_ip = get_ip_for_net(mysql_network)
node.set["mysql"]["bind_address"] = bind_ip

# override default attributes in the upstream mysql cookbook
if platform?(%w{redhat centos amazon scientific})
    node.override["mysql"]["tunable"]["innodb_adaptive_flushing"] = false
end

# ensure there are no other nodes running with this role - there can be only one!
if get_settings_by_role("mysql-master-second", "mysql", false)
  Chef::Application.fatal! "I found another node running with the mysql-master-second role - there can be only one!"
end

# We are the second server, and hence we have to pull the password from the first
if node["mysql"]["myid"].nil?
  # then we have not yet been through setup - try and find first master
  if Chef::Config[:solo]
    Chef::Log.warn("This recipe uses search. Chef Solo does not support search.")
  else
    master_one = search(:node, "chef_environment:#{node.chef_environment} AND mysql_myid:1")
  end

  if master_one.length == 0
    Chef::Log.warn("I cannot yet see the first mysql master to replicate from.
                      Install a node with the mysql-master role and then run me again")
  elsif master_one.length == 1
    # then we have our first master to connect to
    Chef::Log.info("I am mysql master two - getting passwords from mysql master one")
    node.set["mysql"]["tunable"]["repl_pass"] = master_one[0]["mysql"]["tunable"]["repl_pass"]
    node.override["mysql"]["tunable"]["server_id"] = '2'

    node.set["mysql"]["auto-increment-offset"] = "2"

    #now we have set the necessary tunables, install the mysql server
    include_recipe "mysql::server"

    master_one_ip = get_ip_for_net(mysql_network, master_one[0])
    # connect to master
    ruby_block "configure slave" do
      block do
        mysql_conn = Mysql.new(bind_ip, "root", node["mysql"]["server_root_password"])
        command = %Q{
        CHANGE MASTER TO
          MASTER_HOST="#{master_one_ip}",
          MASTER_USER="repl",
          MASTER_PASSWORD="#{node["mysql"]["tunable"]["repl_pass"]}",
          MASTER_LOG_FILE="#{node["mysql"]["tunable"]["log_bin"]}.000001",
          MASTER_LOG_POS=0;
          }
          Chef::Log.info "Sending start replication command to mysql: "
          Chef::Log.info command

        mysql_conn.query("stop slave")
        mysql_conn.query(command)
        mysql_conn.query("start slave")
      end
    end

    # set this last so we can only be found when we are finished
    node.set_unless["mysql"]["myid"] = 2

  elsif master_one.length > 1
    # error out here as something is wrong
    Chef::Application.fatal! "I discovered multiple mysql master one's - there can be only one!"

  end
end

# Cleanup the craptastic mysql default users
ruby_block "cleanup insecure default mysql users" do
  block do
    mysql_conn = Mysql.new(bind_ip, "root", node["mysql"]["server_root_password"])
    Chef::Log.info("Removing insecure default mysql users")
    mysql_conn.query("DELETE FROM mysql.user WHERE User=''")
    mysql_conn.query("DELETE FROM mysql.user WHERE Password=''")
    mysql_conn.query("DROP DATABASE IF EXISTS test")
    mysql_conn.query("FLUSH privileges")
  end
  only_if do
    mysql_conn = Mysql.new(bind_ip, "root", node["mysql"]["server_root_password"])
    exists = mysql_conn.query("SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = 'test'")
    exists.num_rows > 0
  end
end

template "/root/.my.cnf" do
  source "dotmycnf.erb"
  owner "root"
  group "root"
  mode "0600"
  not_if "test -f /root/.my.cnf"
  variables :rootpasswd => node['mysql']['server_root_password']
end

platform_options = node["mysql"]["platform"]

monitoring_procmon "mysqld" do
  service_name = platform_options["mysql_service"]
  process_name service_name
  script_name service_name
end

# This is going to fail for an external database server...
monitoring_metric "mysqld-proc" do
  type "proc"
  proc_name "mysqld"
  proc_regex platform_options["mysql_service"]

  alarms(:failure_min => 1.0)
end

monitoring_metric "mysql" do
  type "mysql"
  host mysql_info["host"]
  user "root"
  password node["mysql"]["server_root_password"]
  port mysql_info["port"]

  alarms("max_connections" => {
           :warning_max => node["mysql"]["tunable"]["max_connections"].to_i * 0.8,
           :failure_max => node["mysql"]["tunable"]["max_connections"].to_i * 0.9
         })

end
