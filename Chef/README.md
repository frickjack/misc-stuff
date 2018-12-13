# TL;DR

Chef cookbooks, etc for various deployments

# Install Chef

Install chef-client on Debian/Ubuntu:
   https://docs.chef.io/packages.html

```
bash installClient.sh
```

# Chef repo structure

https://docs.chef.io/chef_repo.html
```
chef generate repo little-repo
```

# Run chef-client in "zero" mode

```
sudo chef-client --local-mode --node-name littlenode --override-runlist 'role[example]' --why-run
```