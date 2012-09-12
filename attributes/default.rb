default["mysql"]["services"]["db"]["scheme"] = "tcp"
default["mysql"]["services"]["db"]["port"] = 3306
default["mysql"]["services"]["db"]["network"] = "nova"

case platform
when "fedora", "redhat", "centos", "scientific", "amazon"
  default["mysql"]["platform"] = {
    "mysql_service" => "mysqld"
  }
when "ubuntu", "debian"
  default["mysql"]["platform"] = {
    "mysql_service" => "mysql"
  }
end
