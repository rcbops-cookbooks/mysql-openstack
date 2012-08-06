maintainer        "Rackspace US, Inc."
license           "Apache 2.0"
description       "Makes the mysql cookbook behave correctly with OpenStack"
version           "1.0.0"

%w{ ubuntu fedora }.each do |os|
  supports os
end

%w{ mysql osops-utils }.each do |dep|
  depends dep
end
