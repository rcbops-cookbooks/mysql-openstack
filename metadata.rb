name              "mysql-openstack"
maintainer        "Rackspace US, Inc."
license           "Apache 2.0"
description       "Makes the mysql cookbook behave correctly with OpenStack"
version           "4.2.0"

%w{ centos ubuntu }.each do |os|
  supports os
end

%w{ database keepalived mysql openssl osops-utils }.each do |dep|
  depends dep
end
