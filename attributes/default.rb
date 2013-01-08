default["mysql"]["services"]["db"]["scheme"] = "tcp"        # node_attribute
default["mysql"]["services"]["db"]["port"] = 3306           # node_attribute
default["mysql"]["services"]["db"]["network"] = "nova"      # node_attribute


# because of some oddness with bug 993663, we seem to not like the default
# charset to be utf8, but latin-1 instead.
override["mysql"]["tunable"]["character-set-server"] = "latin1"
override["mysql"]["tunable"]["collation-server"] = "latin1_general_ci"

override["mysql"]["tunable"]["log_bin"] = "mysql-binlog"
override["mysql"]["auto-increment-increment"] = "2"


case platform
when "fedora", "redhat", "centos", "scientific", "amazon"
  default["mysql"]["platform"] = {                          # node_attribute
    "mysql_service" => "mysqld"
  }
when "ubuntu", "debian"
  default["mysql"]["platform"] = {                          # node_attribute
    "mysql_service" => "mysql"
  }
end
