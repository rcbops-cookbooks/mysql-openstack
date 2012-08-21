default["mysql"]["services"]["db"]["scheme"] = "tcp"
default["mysql"]["services"]["db"]["port"] = 3306
default["mysql"]["services"]["db"]["network"] = "nova"

case platform
when "fedora", "redhat", "centos"
  default["mysql"]["platform"] = {
    "mysql_service" => "mysqld",
    "build_pkgs" => ["make", "gcc-c++"]
  }
when "ubuntu"
  default["mysql"]["platform"] = {
    "mysql_service" => "mysql",
    "build_pkgs" => ["build-essential"]
  }
end
