default["mysql"]["services"]["db"]["scheme"] = "tcp"
default["mysql"]["services"]["db"]["port"] = 3306
default["mysql"]["services"]["db"]["network"] = "nova"

case platform
when "fedora", "redhat", "centos"
  default["mysql"]["platform"] = {
    "mysql_service" => "mysqld",
    "build_pkgs" => ["make", "gcc-c++"],
    "service_bin" => "/sbin/service"
  }
when "ubuntu"
  default["mysql"]["platform"] = {
    "mysql_service" => "mysql",
    "build_pkgs" => ["build-essential"],
    "service_bin" => "/usr/sbin/service"
  }
end
