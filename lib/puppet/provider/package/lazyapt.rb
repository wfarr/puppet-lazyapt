Puppet::Type.type(:package).provide :lazyapt, :parent => :apt, :source => :dpkg do
  desc "Package management via `apt-get` done fucking right."

  commands :aptget => "/usr/bin/apt-get"
  commands :aptcache => "/usr/bin/apt-cache"
  commands :preseed => "/usr/bin/debconf-set-selections"

  has_feature :versionable

  alias before_install, install

  def before_install
    unless version_available? @resource[:name], @resource[:version]
      update_packages
    end

    install
  end

  def update_packages
    unless self.class.const_defined?(:APT_GET_UPDATED) && self.APT_GET_UPDATED
      notice "Running apt-get update to refresh package versions"
      aptget :update rescue nil
      self.class.const_set(:APT_GET_UPDATED, true)
    end
  end

  def version_available?(name, version)
    available_packages.has_key? name &&
      available_packages[name].member? version
  end

  def available_packages
    AVAILABLE_PACKAGES ||= generate_available_packages_map
  end

  def generate_available_packages_map
    output = `#{commands(:aptcache)} dumpavail | grep Package -A 6`
    serialized = YAML.load(output.split("\n--\n"))

    packages_map = {}

    serialized.each do |pkg|
      pname = pkg["Package"]
      pver = pkg["Version"]

      if packages_map.has_key? pname
        packages_map[pname] = packages_map[pname] << pver
      else
        packages_map[pname] = [pver]
      end
    end

    packages_map
  end
end