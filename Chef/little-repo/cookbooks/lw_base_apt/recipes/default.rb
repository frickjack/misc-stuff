#
# apt install a bunch of random stuff ...
#

['apt-transport-https', 'curl', 'git', 'gpg', 'less', 'vim'].each do |name|
  package 'g3-base-'+name do
    package_name name
  end
end
