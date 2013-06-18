default["mysql"]["services"]["db"]["scheme"] = "tcp"        # node_attribute
default["mysql"]["services"]["db"]["port"] = 3306           # node_attribute
default["mysql"]["services"]["db"]["network"] = "management"      # node_attribute

default["mysql"]["ha"]["vrid"] = 10

# because of some oddness with bug 993663, we seem to not like the default
# charset to be utf8, but latin-1 instead.
override["mysql"]["tunable"]["character-set-server"] = "latin1"
override["mysql"]["tunable"]["collation-server"] = "latin1_general_ci"

override["mysql"]["tunable"]["binlog_format"]    = "statement"
override["mysql"]["tunable"]["log_bin"] = "mysql-binlog"
override["mysql"]["auto-increment-increment"] = "2"

override["mysql"]["tunable"]["log-queries-not-using-index"] = false


case platform
when "fedora", "redhat", "centos", "scientific", "amazon"
  default["mysql"]["platform"] = {                          # node_attribute
    "mysql_service" => "mysqld",
    "service_bin" => "/sbin/service"
  }
when "ubuntu", "debian"
  default["mysql"]["platform"] = {                          # node_attribute
    "mysql_service" => "mysql",
    "service_bin" => "/usr/sbin/service"
  }
end
