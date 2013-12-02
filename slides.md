# How to automate infrastructure with Chef?

Grégoire Pineau - SymfonyCon - Warsaw 2013

------------------

## Why do you need to automate everything?

------------------

### From where do you use to deploy?

* from your computer
* from a staging
* from a preprod
* from a dedicated server
* directly in production
* ...

------------------

### Some years ago...

Install

```bash
$ git clone git@mycompany.com:project
```

Or update

```bash
$ git fetch -t
```

Then

```bash
git checkout -q -f v1.0.0

php symfony build:all --all --no-confirmation
php symfony plugin:install
php symfony projects:fix-perms
php symfony clear:cache

rsync -azCcv --delete --dry-run . www-data@project.com:/var/www/project
```

------------------

### And now?

```bash
git checkout -q -f v1.0.0

php composer.phar install --optimize-autoloader
bowser install

grunt build

php app/console assetic:dump

rsync -azCcv --delete --dry-run . prod:/var/www/project

ssh prod php /var/www/project/app/console --env="prod" clear:cache
ssh prod php /var/www/project/app/console --env="prod" doctrine:migrations:migrate
```

------------------

### There are a few issues here!

Actually, all theses issue are not related to manual deployment. But theses
can be easily catch and treat with automation.

* `composer install` can fail because:
    * github is down
    * satis is down
* `bower install` can fail because:
    * github is down
* Doctrine migrations can fail
* It is hard to rollback

------------------

### You need to automate all theses steps and catch failures !!!

------------------

## Some numbers:

------------------

### Survey from puppetlabs

* Deploy frequency **on demand**:
    * **8%** => without automated toolchain
    * **27%** => with automated toolchain
* Mean time to recover **< 1 hour**:
    * **17%** => without automated toolchain
    * **47%** => with automated toolchain

------------------

### Amazon

* May 2011 Deployment Stats:
* Production hosts
* 11.6 seconds: Mean time between deployments (weekday)
* 1,079: Max # of deployments in a single hour

------------------

### Etsy

* 196 differents people deployed to prod
* 25 deploys per day

------------------

### Github

* 50 deploys per day
* busiest day yet, Aug. 23, 563 builds and 175 deploys.

------------------

### SensioLabs

* symfony.com: 1 deploy every 15 minutes
* insight.sensiolabs.com: 1-10 deploy each days

------------------

### Facebook

> At some point you have to deal with reality. You can postpone automation for
> a long time and make your life really, really difficult. But at some point
> your life goes from difficult to impossible.

Phil Dibowitz, Production Engineer at Facebook

------------------

### Conclusion

* automate deploys
* deploy small changset
* deploy often
* deploy everything by using feature flags

------------------

### Tips: Feature flags / usage

Hide features before they are totally ready.

In our templates:

```jinja
{% if is_granted('FEATURE_SECRET') }
    <a href="#..."></a>
{% endif %}
```

In our controllers:

```php
public function secretAction()
{
    if (!$this->get('security.context')->isGranted('FEATURE_SECRET')) {
        throw new AccessDeniedException('You are not allowed to see this feature.');
    }
}
```

------------------

### Tips: Feature flags / implementation

```xml
<!-- service.xml -->
<service id="awesome.feature_hierarchy.voter" class="%security.access.role_hierarchy_voter.class%">
    <argument type="service" id="security.role_hierarchy" />
    <argument>FEATURE_</argument>
    <tag name="security.voter" />
</service>
```

```php
// class User implement UserInterface
public function getRoles()
{
    if ($this->isAdmin) {
        return array('ROLE_ADMIN', 'FEATURE_BETA');
    }

    return array('ROLE_USER', 'FEATURE_PROD');
}
```

```yaml
# security.yml
role_hierarchy:
    ROLE_ADMIN: ROLE_USER
    FEATURE_BETA: FEATURE_PROD, FEATURE_SECRET
    FEATURE_PROD: FEATURE_FOO, FEATURE_BAR
```


------------------

### Tips: Feature flags / release the feature


```diff
# security.yml
role_hierarchy:
    ROLE_ADMIN: ROLE_USER
-   FEATURE_BETA: FEATURE_PROD, FEATURE_SECRET
-   FEATURE_PROD: FEATURE_FOO, FEATURE_BAR
+   FEATURE_BETA: FEATURE_PROD
+   FEATURE_PROD: FEATURE_FOO, FEATURE_BAR, FEATURE_SECRET
```


More information: [Feature Flags With Symfony2](http://marc.weistroff.net/2012/01/09/simple-feature-flags-symfony2)

------------------

## How to automate everything?

------------------

### Shell script

Just copy what you used to do to deploy inside a shell script

* But this does not handle failure, we have to deal with it
* This is hard to maintain
* There is not builtin / open-source template => you have to create everything

------------------

### [Fabric](http://docs.fabfile.org/en/1.8/) (python)

> Fabric is a Python (2.5 or higher) library and command-line tool for
> streamlining the use of SSH for application deployment or systems
> administration tasks.

So it is:

* basically a process manager
* ssh wrapper
* very flexible
* **not a framework**
* useful to deploy or install
* python ☺

------------------

```python
# fabfile.py
# ...

def install():
    sudo('mkdir -p ' + path)
    with cd(path):
        sudo('git clone ' + repo + ' .')
        sudo('composer install --dev')
        sudo('php app/console doctrine:database:create')
        sudo('php app/console doctrine:migrations:migrate --no-interaction')

def update():
    with cd(path):
        sudo('git fetch')
        sudo('git reset --hard origin/prod')
        sudo('composer install')
        sudo('php app/console doctrine:migrations:migrate --no-interaction')
```

Then:

* `fab prod update` to deploy
* `fab localhost install` to install the project on our laptop

------------------

### [Capistrano](http://capifony.org/) / Capifony

* Capifony is a tool build on top of Capistrano and specialized for Symfony
* **A framework** for application deployment

------------------

```ruby
# deploy.rb

set   :application,   "My App"
set   :deploy_to,     "/var/www/my-app.com"
set   :domain,        "my-app.com"

set   :scm,           :git
set   :repository,    "ssh-gitrepo-domain.com:/path/to/repo.git"

role  :web,           domain
role  :app,           domain, :primary => true

set   :use_sudo,      false
set   :keep_releases, 3
```

Then run:

    cap deploy

------------------

### Conclusion

* Capifony is better to
    * deploy if you want something simple
* Fabric is better to:
    * migrate shell script to something more maintainable
    * create maintenance tasks (db export, run symfony command, clean log, ...)
    * create a very custom deploy process

------------------

## But

![](assets/deeper.jpg)

------------------

* Now we have tools to automate:
    * recurrent tasks
    * punctual tasks ; yes, this too
    * deploy
* But we also need tools to automate infrastructure:
    * Because I want the same PHP version on all my machines
    * Because I want the same nginx version on all my machines
    * ...
* So I can choose:
    * [Ansible](https://github.com/ansible/ansible)
    * [Puppet](http://puppetlabs.com/)
    * [Chef](http://www.opscode.com/chef/)
    * [Saltstack](http://www.saltstack.com/)
    * [Cfengine](http://cfengine.com/)

------------------

## Chef

------------------

### What is Chef?

> Chef is built to address the hardest infrastructure challenges on the planet.
> By modeling IT infrastructure and application delivery as code, Chef provides
> the power and flexibility to compete in the digital economy.

------------------

![](assets/wat.jpg)

------------------

### What is Chef / My vision


* Chef is **a framework** (in Ruby).
* Chef is **idempotent**.
* Chef helps to build new machines.
* Chef helps to update existing machines.
* Chef helps to **keep a history** of all modifications in infrastructure.
* Chef helps to deploy.

------------------

### How to test chef:

* In a virtual machine (Vagrant)
* In the cloud (EC2, ...)
* On our laptop, but it's not a good idea

------------------

### What is [Vagrant](http://www.vagrantup.com/)?

> Create and configure lightweight, reproducible, and portable development
> environments.

* Vagrant is a tools able to boot and provision VM.
* It supports different providers VirtualBox, VMWare, LXC, dockr, ...
* Try it with:

    ``` bash
    $ vagrant box add base http://files.vagrantup.com/lucid32.box
    $ vagrant init
    $ vagrant up
    ```

------------------

### With vagrant:

* you can have the **same** environment from developer's to production's machine
* you can test new PHP versions
* you can add a new developer on our project very fast
* ...

------------------

### But vagrant:

* is slow
* but you can [tweak it](http://www.whitewashing.de/2013/08/19/speedup_symfony2_on_vagrant_boxes.html)
* does not include provisioning => Chef.

------------------

### Tips: Vagrant #1

* Make sure that vagrant version is up to date
* If you use virtualbox, make sure that the host and the guest share the same version
  of VirtualBox Guest additions (there's a vagrant plugin for that)
* You can find lot boxes here: [http://www.vagrantbox.es/](http://www.vagrantbox.es/)

------------------

### How does Chef work?

* Chef needs a chef server
    * This server knows the state of each machine, called `node`.
    * You can use opscode's one
    * You can host our own
* Chef (`chef-client`) need to be installed on the target machine. (Prod, preprod, vm, ...)

    ``` bash
    $curl -L https://www.opscode.com/chef/install.sh | bash
    ```
* Then run `chef-client` on the node you want to update

------------------

### Chef solo

But chef can also work in a standalone mode with `chef-solo`.
So in this case, `chef-solo` doest not need a chef server. Every `cookbook` should
be inside the `node`.

------------------

### Chef client

* When you run `chef-client` on a `node`, chef will
    1. Fetch the latest `cookbook`s from the Chef Server
    1. Execute a run list
* A run list is a list of `cookbook`s (`nginx`, `php`) to execute
* A `cookbook` is a list of `recipe`s (`php[default]`, `php[module_gd]`, `php[module_...]`)
    * The `default` recipe is executed by default
* A `recipe` define how to install a software, or a module

------------------

### Quickstart

------------------

#### Create a new VM

Create a new VM with vagrant

```bash
$ vagrant box add saucy64 http://cloud-images.ubuntu.com/vagrant/saucy/current/saucy-server-cloudimg-amd64-vagrant-disk1.box
$ vagrant init
$ sed -i 's/"base"/"saucy64"/' Vagrantfile
```

------------------

### Tips: Vagrant #2

If our host is a 32bit plateform and the guest is a 64bits plateform, add this
to the `Vagrantfile`:

``` ruby
config.vm.provider :virtualbox do |vb|
    vb.customize ["modifyvm", :id, "--ostype", "Ubuntu_64"]
end
```

------------------

#### boot the machine

```bash
$ vagrant up
$ vagrant ssh
```

------------------

#### Install chef

To make things easier, we will use `chef-solo`. So we will not use a Chef
Server.

```bash
$ sudo su
$ cd
$ curl -L https://www.opscode.com/chef/install.sh | bash
```

**Note:** Chef is already installed in this box.

------------------

#### Init our chef repository

Download opscode's skeleton:

```bash
$ wget http://github.com/opscode/chef-repo/tarball/master
$ tar -zxf master && mv opscode-chef-repo* chef-repo && rm master
$ cd chef-repo
```

It looks like:

```
chef-repo
├── certificates/
├── chefignore
├── config/
├── cookbooks/       <--- most important folder
├── data_bags/
├── environments/
├── LICENSE
├── Rakefile
├── README.md
└── roles/
```

------------------

#### community cookbook

* [http://community.opscode.com/cookbooks](http://community.opscode.com/cookbooks)
* you can download them as vendors, but ...
* you can instead fetch them:
    * with [berkshelf](http://berkshelf.com/)
    * with [librarian-chef](https://github.com/applicationsonline/librarian-chef)
* (We use the latter)

------------------

#### Create the first cookbook

```bash
$ knife cookbook create fortune
```

```
fortune
├── attributes
├── definitions
├── files
│   └── default
├── libraries
├── metadata.rb
├── providers
├── README.md
├── recipes
│   └── default.rb   <--- most important file
├── resources
└── templates
    └── default
```

------------------

#### Create the first recipe

```
# recipes/default.rb

include_recipe "apache2"
include_recipe "mysql::client"
include_recipe "mysql::server"
include_recipe "mysql::ruby"
include_recipe "php"
include_recipe "php::module_mysql"
include_recipe "apache2::mod_php5"

apache_site "default" do
  enable true
end

mysql_database fortune do
  connection ({:host => 'localhost', :username => 'root', :password => node['mysql']['server_root_password']})
  action :create
end
```

------------------

#### Working with attributes

```diff
-mysql_database 'fortune' do
+mysql_database node['fortune']['database'] do
   connection ({:host => 'localhost', :username => 'root', :password => node['mysql']['server_root_password']})
   action :create
end
```

Let's create an attribute file:

``` ruby
# attributes/default.rb
default["fortune"]["database"] = "fortune"
default["fortune"]["ga"] = "GA_123456789"
```

Now, you can override attributes:

* For an environment (prod/preprod)
* For a node
* For a role (`front` / `api` / `database` / `consumer` / ...)

------------------

### Popular / Usefull cookbook:

* `database` + `postgresql`: Because it's better than mysql ☺
* `wal_e` (https://github.com/house9/wal-e-cookbook)
* `git`
* `nginx` + `nginx-fastcgi`
* `php`
* `nodejs`
* `python`
* `rabbitmq`
* `varnish`
* `elasticsearch` (http://github.com/elasticsearch/cookbook-elasticsearch)
* `postfix`
* `cronwrap` (https://github.com/smaftoul/cronwrap)

------------------

### Deploy with Chef / Structure

```
/var/www/insight/
├── current -> /var/www/insight/releases/d3fd36569dffda711a2770ea1ccae28d54fb9c11
├── releases
│   ├── 43d7d8f9aae517d45c8ca57d96d11e0648171cf9
│   ├── 52c1593bd2e6ed9496ea063d1d94aa6621b39c37
│   ├── 981a27a9932767947353d2d8567ca1b0a3f87b13
│   ├── 9d2f7873d2263f44da730efae9d6dcdbe0ffd430
│   └── d3fd36569dffda711a2770ea1ccae28d54fb9c11
└── shared
    ├── app
    ├── cached-copy
    └── vendor
```

------------------

### Deploy with Chef / process

We use the `application` cookbook.

``` ruby
application node[cookbook_name]['app_name'] do
  revision node[cookbook_name]['deploy_revision']

  env_vars_composer = {}
  env_vars_composer["DATABASE_NAME"] = node[cookbook_name]['dbname']
  env_vars_composer["DATABASE_USER"] = node[cookbook_name]['dbuser']
  env_vars_composer["DATABASE_PASSWORD"] = node[cookbook_name]['dbpassword']
  # ...

  # A this point, the code is not yet checkouted
  before_deploy do
    %w(app/sessions app/logs vendor).each do |dir|
      directory "#{shared_path}/#{dir}" do
        owner new_resource.owner
        action :create
        recursive true
      end
    end
  end

  # A this point, the code is checkouted, but not yet deployed
  before_migrate do
    template "#{release_path}/web/maintenance-dist.html" do
      source "maintenance.html.erb"
      user new_resource.owner
      mode 00644
      variables(
        'sitename' => node[cookbook_name]['app_name'].capitalize
      )
    end

    file "#{release_path}/web/app_dev.php" do
      action :delete
    end

    execute "bower install" do
      environment({
        'HOME' => node['etc']['passwd']['insight']['dir'],
        'GIT_SSH' => "#{node[cookbook_name]['app_path']}/deploy-ssh-wrapper"
      })
      cwd release_path
      user new_resource.owner
    end

    bash "copy shared vendors into current release" do
      code <<-EOH
cp -pa #{new_resource.shared_path}/vendor #{new_resource.release_path}
EOH
      only_if { ::File.directory?("#{new_resource.shared_path}/vendor") }
      user new_resource.owner
    end

    execute "php /opt/composer.phar install --dev --prefer-source --no-interaction --optimize-autoloader" do
      environment env_vars_composer
      cwd release_path
      user new_resource.owner
    end

    execute "php app/console assetic:dump --env=prod --no-debug" do
      cwd release_path
      user new_resource.owner
    end

    bash "migrate database if needed" do
      user new_resource.owner
      cwd release_path
      code <<-EOH
MIGRATION_NEEDED=0
DEFAULT_CONNECTION=$(app/console doctrine:migrations:status --show-versions | grep "not migrated" | wc -l)
if [ "$DEFAULT_CONNECTION" -ne "0" ]; then
MIGRATION_NEEDED="1"
fi

if [ "$MIGRATION_NEEDED" -ne "0" ]; then
cp web/maintenance-dist.html #{node[cookbook_name]['app_path']}/current/web/maintenance.html
app/console doctrine:migrations:migrate --no-interaction --env=prod --no-debug
EXIT_CODE=$?
rm #{node[cookbook_name]['app_path']}/current/web/maintenance.html
echo '#{node[cookbook_name]['metric_prefix']}.chef.application.db-migrated.count:1|c' | nc -w 1 -u #{statsd_host} 8125
fi
exit $EXIT_CODE
EOH
      only_if 'app/console list --raw | grep "doctrine:migrations:status"', :user => new_resource.owner, :cwd => release_path
    end
  end

  symlinks({
    'app/sessions' => 'app/sessions',
    'app/logs' => 'app/logs',
  })

  before_restart do
    service "php5-fpm" do
      action :restart
    end
  end

  after_restart do
    bash "Copy installed vendor to shared vendor" do
      code <<-EOH
cp -pa #{new_resource.release_path}/vendor #{new_resource.shared_path}
EOH
    end
  end
end
```

------------------

### Deploy with Chef - What to keep in mind

* try to cache composer (see [m6web's blogpost](http://tech.m6web.fr/composer-installation-without-github.html))
* try to cache bower
* use [Incenteev/ParameterHandler](https://github.com/Incenteev/ParameterHandler). Thanks [stof](https://github.com/stof), REALLY !!
* move the session outside the cache
* don't forget symlinks (`app/logs`, `app/session`)
* do not share `vendor`.
* do not forgot to restart php-fpm
* do not forgot to optimize autoloader `composer dump-autoload --optimize`

------------------

### Conclusion

* Chef helps us deploy **faster and safer**
* Chef helps create / restore an infra very fast (~20 minutes)
* Chef is not easy
* Chef is written in ruby
* Chef is (IMHO) not mature enough:
    * the community is small
    * cookbooks are often broken
    * you need to sign a CLA to contribute
    * PRs can stay open for more than 1 year before a first review

------------------

## Big conclusion ☺

* Automate EVERYTHING!
* with the proper tool

------------------

# Thanks! Questions?

* Slide are available on [github](https://github.com/lyrixx/SFCon-Warsaw2013-Automation)
* Otherwise:
    * [http://twitter.com/lyrixx](http://twitter.com/lyrixx)
    * [http://github.com/lyrixx](http://github.com/lyrixx)
    * [http://blog.lyrixx.info](http://blog.lyrixx.info)
* And:
    * [We are hiring](http://sensiolabs.com/fr/nous_rejoindre/pourquoi_nous_rejoindre.html)

------------------

# Sources:

* http://assets.en.oreilly.com/1/event/60/Velocity%20Culture%20Presentation.pdf
* http://www.slideshare.net/beamrider9/continuous-deployment-at-etsy-a-tale-of-two-approaches
* https://github.com/blog/1241-deploying-at-github
* http://gettingstartedwithchef.com
