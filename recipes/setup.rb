#
# Cookbook Name:: mysql-openstack
# Recipe:: setup
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

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

# ensure there are no other nodes running with this role - there can be only one!
if get_settings_by_role("mysql-setup", "mysql", false)
  Chef::Application.fatal! "I found another node running with the mysql-setup role - there can be only one!"
end

# set passwords
if node["developer_mode"]
  node.set_unless["mysql"]["tunable"]["repl_pass"] = "replication"
else
  node.set_unless["mysql"]["tunable"]["repl_pass"] = secure_password
end
