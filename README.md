## Welcome to GitLab

GitLab is a free Project/Repository managment application

## Application details

* rails 3.1
* works only with gitosis
* sqlite as default db 


## Requirements

* ruby 1.9.2
* sqlite
* git
* gitosis
* ubuntu/debian
* pygments lib  - sudo easy_install pygments

## Install Project

```bash
git clone git://github.com/gitlabhq/gitlabhq.git
cd gitlabhq/

# install this library first
sudo easy_install pygments

sudo gem install bundler
bundle

RAILS_ENV=production rake db:setup
  
# create admin user 
# login....admin@local.host
# pass.....5iveL!fe
RAILS_ENV=production rake db:seed_fu 
```

Install gitosis, edit conf/gitosis.yml & start server

```bash
rails s -e production
```

## Install Gitosis

```bash
sudo aptitude install gitosis

sudo adduser \
  --system \
  --shell /bin/sh \
  --gecos 'git version control' \
  --group \
  --disabled-password \
  --home /home/git \
  git

ssh-keygen -t rsa

sudo -H -u git gitosis-init < ~/.ssh/id_rsa.pub
sudo chmod 755 /home/git/repositories/gitosis-admin.git/hooks/post-update
```

## Install ruby 1.9.2

```bash
sudo aptitude install git-core curl gcc checkinstall libxml2-dev libxslt-dev sqlite3 libsqlite3-dev  libcurl4-openssl-dev libreadline5-dev libc6-dev libssl-dev libmysql++-dev make build-essential zlib1g-dev

wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-p290.tar.gz

tar xfvz ruby-1.9.2-p290.tar.gz

cd ruby-1.9.2-p290
./configure
make
sudo checkinstall -D

sudo gem update --system

echo "gem: --no-rdoc --no-ri" > ~/.gemrc
```

