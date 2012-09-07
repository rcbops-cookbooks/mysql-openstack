maintainer        "Rackspace US, Inc."
license           "Apache 2.0"
description       "Makes the mysql cookbook behave correctly with OpenStack"
version           "1.0.3"

%w{ ubuntu fedora redhat centos }.each do |os|
  supports os
end

%w{ database monitoring mysql osops-utils }.each do |dep|
  depends dep
end
