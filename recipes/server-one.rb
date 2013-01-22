#
# Cookbook Name:: mysql-openstack
# Recipe:: server-one
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

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

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
if get_settings_by_role("mysql-master", "mysql", false)
  Chef::Application.fatal! "You can only have one node with the glance-setup role"
end

# We are the first server, and hence we get to set the passwords

if node["mysql"]["myid"].nil?
  # then we have not yet been through setup

    Chef::Log.info("I am mysql master one - setting passwords")
    node.override["mysql"]["tunable"]["server_id"] = '1'
    if node["developer_mode"]
      node.set_unless["mysql"]["tunable"]["repl_pass"] = "replication"
    else
      node.set_unless["mysql"]["tunable"]["repl_pass"] = secure_password
    end

    node.set["mysql"]["auto-increment-offset"] = "1"

    # now we have set the necessary tunables, install the mysql server
    include_recipe "mysql::server"

    # since we are master one, create the replication user
    mysql_connection_info = {:host => bind_ip , :username => 'root', :password => node['mysql']['server_root_password']}

    mysql_database_user 'repl' do
      connection mysql_connection_info
      password node["mysql"]["tunable"]["repl_pass"]
      action :create
    end

    mysql_database_user 'repl' do
      connection mysql_connection_info
      privileges ['REPLICATION SLAVE']
      action :grant
      host '%'
    end

    # set this last so we can only be found when we are finished
    node.set_unless["mysql"]["myid"] = "1"
end

if node['mysql']['myid'] == '1'
  # we are master one (and by virtue of that value being set, we have also 
  # been through setup) but have we connected back to master two yet?
  if Chef::Config[:solo]
    Chef::Log.fatal("This recipe uses search. Chef Solo does not support search.")
  else
    master_two = search(:node, "chef_environment:#{node.chef_environment} AND mysql_myid:2")
  end

  if master_two.length == 1
    Chef::Log.info("I am the first mysql master, and I have found the second mysql master")

    master_two_ip = get_ip_for_net(mysql_network, master_two[0])

    # attempt to connect to second master as a slave
    ruby_block "configure slave" do
      block do
        mysql_conn = Mysql.new(bind_ip, "root", node["mysql"]["server_root_password"])
        command = %Q{
        CHANGE MASTER TO
          MASTER_HOST="#{master_two_ip}",
          MASTER_USER="repl",
          MASTER_PASSWORD="#{node["mysql"]["tunable"]["repl_pass"]}",
          MASTER_LOG_FILE="#{node["mysql"]["tunable"]["log_bin"]}.000001",
          MASTER_LOG_POS=0;
          }
        Chef::Log.info("Attempting to connect back to second master as a slave")
        Chef::Log.info "Sending start replication command to mysql: "
        Chef::Log.info command

        mysql_conn.query("stop slave")
        mysql_conn.query(command)
        mysql_conn.query("start slave")
      end

      not_if do
        #TODO this fails if mysql is not running - check first
        mysql_conn = Mysql.new(bind_ip, "root", node["mysql"]["server_root_password"])
        slave_sql_running = ""
        mysql_conn.query("show slave status") {|r| r.each_hash {|h| slave_sql_running = h['Slave_SQL_Running'] } }
        slave_sql_running == "Yes"
      end

    end

  elsif master_two.length > 1
    Chef::Log.warn("I found more than one mysql-master-two. Cannot setup replication")
  else
    Chef::Log.info("I am currently the only mysql master - nothing to do here")
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
