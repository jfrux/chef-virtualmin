#
# Cookbook Name:: virtualmin
# Recipe:: default
#
# Copyright 2013, Steven Barre
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

# Base virtualmin package
base_pkgs="virtualmin-base"

# Packages to check for updates
update_pkgs = value_for_platform(
  [ 'redhat', 'centos' ] => {
    ["5.0", "5.1", "5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9" ] => %w{ bind bind-utils caching-nameserver httpd postfix spamassassin procmail perl-DBD-Pg perl-DBD-MySQL quota iptables openssl python mailman subversion mysql mysql-server mysql-devel postgresql postgresql-server logrotate webalizer php php-xml php-gd php-imap php-mysql php-odbc php-pear php-pgsql php-snmp php-xmlrpc php-mbstring mod_perl mod_python cyrus-sasl dovecot spamassassin mod_dav_svn cyrus-sasl-gssapi mod_ssl ruby ruby-devel rubygems perl-XML-Simple perl-Crypt-SSLeay },
    [ "6.0", "6.1", "6.2", "6.3", "6.4", "6.5", "6.6", "6.7", "6.8", "6.9" ] => %w{ bind bind-utils httpd postfix spamassassin procmail perl-DBD-Pg perl-DBD-MySQL quota iptables openssl python mailman subversion mysql mysql-server mysql-devel postgresql postgresql-server logrotate webalizer php php-xml php-gd php-imap php-mysql php-odbc php-pear php-pgsql php-snmp php-xmlrpc php-mbstring mod_perl mod_python cyrus-sasl dovecot spamassassin mod_dav_svn cyrus-sasl-gssapi mod_ssl ruby ruby-devel rubygems perl-XML-Simple perl-Crypt-SSLeay }
  }
)

# Let login for file downloads and repo path
if node['virtualmin']['serial_number'] == 'GPL'
  login = ''
  repopath = "gpl/"
else
  login = node['virtualmin']['serial_number'] + ":" + node['virtualmin']['license_key'] + "@"
  repopath = ""
end

# Fix weird arch values
case node['kernel']['machine']
  when 'i686','i386','i586'
    arch = 'i386'
  else
    arch = node['kernel']['machine']
end

# Check that localhost is defined in the hosts file
has_localhost = Mixlib::ShellOut.new("grep localhost /etc/hosts")
has_localhost.run_command
if has_localhost.exitstatus != 0
  Chef::Application.fatal!("There is no localhost entry in /etc/hosts."+has_localhost.exitstatus.to_s)
end  

# Disable SELinux
if platform_family?("rhel")
  include_recipe "selinux::permissive"
end

# Virtualmin License file
template "/etc/virtualmin-license" do
  source "virtualmin-license.erb"
  mode 0700
  owner "root"
  group "root"
end

case node["platform"]
  when "redhat", "centos"
    remote_file "#{Chef::Config[:file_cache_path]}/virtualmin-release-latest.noarch.rpm" do
      source "http://#{login}software.virtualmin.com/#{repopath}#{node['platform']}/#{node['platform_version']}/#{arch}/virtualmin-release-latest.noarch.rpm"
      not_if "rpm -qa | grep -q '^virtualmin-release-'"
      notifies :install, "rpm_package[virtualmin-release]", :immediately
    end

    rpm_package "virtualmin-release" do
      source "#{Chef::Config[:file_cache_path]}/virtualmin-release-latest.noarch.rpm"
      only_if { ::File.exists?("#{Chef::Config[:file_cache_path]}/virtualmin-release-latest.noarch.rpm") }
      action :nothing
    end

    file "virtualmin-release-cleanup" do
      path "#{Chef::Config[:file_cache_path]}/virtualmin-release-latest.noarch.rpm"
      action :delete
    end

    # force nightly sa-update
    file "/etc/sysconfig/sa-update" do
      content "SAUPDATE=yes"
    end

  when "debian", "ubuntu"
    #TODO
end

package base_pkgs do
  action :upgrade
end

update_pkgs.each do |pkg|
  package pkg do
    action :upgrade
  end
end

