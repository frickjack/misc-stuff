#
# Setup custom apt repo, then install
#  * https://docs.docker.com/install/linux/docker-ce/debian/#install-docker-ce-1
#  * https://docs.docker.com/compose/install/#install-compose
#

include_recipe 'g3_base_apt'

apt_repository 'docker-apt-repo' do
  uri   'https://download.docker.com/linux'
  key   'https://download.docker.com/linux/debian/gpg'
  components ['stable']
end

